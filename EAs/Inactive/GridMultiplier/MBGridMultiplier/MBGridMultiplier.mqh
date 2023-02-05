//+------------------------------------------------------------------+
//|                                                    MBGridMultiplier.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <SummitCapital\Framework\EA\EA.mqh>
#include <SummitCapital\Framework\Helpers\EAHelper.mqh>
#include <SummitCapital\Framework\Constants\MagicNumbers.mqh>

#include <SummitCapital\Framework\Objects\GridTracker.mqh>
#include <SummitCapital\Framework\Objects\Dictionary.mqh>

class MBGridMultiplier : public EA<SingleTimeFrameEntryTradeRecord, PartialTradeRecord, SingleTimeFrameExitTradeRecord, SingleTimeFrameErrorRecord>
{
public:
    MBTracker *mMBT;
    GridTracker *mGT;
    Dictionary<int, int> *mLevelsWithTickets;

    int mStartingNumberOfLevels;
    double mMinLevelPips;
    double mLotSize;
    double mMaxEquityDrawDown;

    bool mFirstTrade;
    bool mLastXCandlesPastEMA;

    double mStartingEquity;
    int mPreviousAchievedLevel;
    bool mCloseAllTickets;

public:
    MBGridMultiplier(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
                     CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
                     CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter, MBTracker *&mbt, GridTracker *&gt);
    ~MBGridMultiplier();

    void GetGridLevelsAndDistance(double totalDistance, int &levels, double &levelDistance);

    virtual double RiskPercent() { return mRiskPercent; }

    virtual void PreRun();
    virtual bool AllowedToTrade();
    virtual void CheckSetSetup();
    virtual void CheckInvalidateSetup();
    virtual void InvalidateSetup(bool deletePendingOrder, int error);
    virtual bool Confirmation();
    virtual void PlaceOrders();
    virtual void ManageCurrentPendingSetupTicket();
    virtual void ManageCurrentActiveSetupTicket();
    virtual bool MoveToPreviousSetupTickets(Ticket &ticket);
    virtual void ManagePreviousSetupTicket(int ticketIndex);
    virtual void CheckCurrentSetupTicket();
    virtual void CheckPreviousSetupTicket(int ticketIndex);
    virtual void RecordTicketOpenData();
    virtual void RecordTicketPartialData(Ticket &partialedTicket, int newTicketNumber);
    virtual void RecordTicketCloseData(Ticket &ticket);
    virtual void RecordError(int error, string additionalInformation);
    virtual bool ShouldReset();
    virtual void Reset();
};

MBGridMultiplier::MBGridMultiplier(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
                                   CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
                                   CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter, MBTracker *&mbt, GridTracker *&gt)
    : EA(magicNumber, setupType, maxCurrentSetupTradesAtOnce, maxTradesPerDay, stopLossPaddingPips, maxSpreadPips, riskPercent, entryCSVRecordWriter, exitCSVRecordWriter, errorCSVRecordWriter)
{
    mMBT = mbt;
    mGT = gt;
    mLevelsWithTickets = new Dictionary<int, int>();

    mStartingNumberOfLevels = 0;
    mMinLevelPips = 0;
    mLotSize = 0.0;
    mMaxEquityDrawDown = 0.0;

    mFirstTrade = true;
    mLastXCandlesPastEMA = false;

    mStartingEquity = 0;
    mPreviousAchievedLevel = 1000;
    mCloseAllTickets = false;

    EAHelper::FindSetPreviousAndCurrentSetupTickets<MBGridMultiplier>(this);
    EAHelper::UpdatePreviousSetupTicketsRRAcquried<MBGridMultiplier, PartialTradeRecord>(this);
    EAHelper::SetPreviousSetupTicketsOpenData<MBGridMultiplier, SingleTimeFrameEntryTradeRecord>(this);
}

MBGridMultiplier::~MBGridMultiplier()
{
    delete mLevelsWithTickets;
}

void MBGridMultiplier::PreRun()
{
    mMBT.DrawNMostRecentMBs(-1);
    mGT.Draw();
}

bool MBGridMultiplier::AllowedToTrade()
{
    return EAHelper::BelowSpread<MBGridMultiplier>(this) && EAHelper::WithinTradingSession<MBGridMultiplier>(this);
}

void MBGridMultiplier::CheckSetSetup()
{
    if (iBars(mEntrySymbol, mEntryTimeFrame) <= BarCount())
    {
        return;
    }

    if (mMBT.GetNthMostRecentMBsType(0) == SetupType())
    {
        MBState *tempMBState;
        if (!mMBT.GetNthMostRecentMB(0, tempMBState))
        {
            return;
        }

        if (SetupType() == OP_BUY)
        {
            if (iLow(mEntrySymbol, mEntryTimeFrame, 1) < iHigh(mEntrySymbol, mEntryTimeFrame, tempMBState.HighIndex()))
            {
                if (CandleStickHelper::BrokeFurther(OP_BUY, mEntrySymbol, mEntryTimeFrame, 1))
                {
                    int currentRetracementIndex = EMPTY;
                    if (!mMBT.CurrentBullishRetracementIndexIsValid(currentRetracementIndex))
                    {
                        return;
                    }

                    double totalUpperDistance = iHigh(mEntrySymbol, mEntryTimeFrame, currentRetracementIndex) - CurrentTick().Bid();
                    int totalUpperLevels = 0;
                    double upperLevelDistance = 0.0;
                    GetGridLevelsAndDistance(totalUpperDistance, totalUpperLevels, upperLevelDistance);

                    if (totalUpperLevels == 0)
                    {
                        Print("No Upper Levels. Total Distance: ", totalUpperDistance, ", Upper Level Distance: ", upperLevelDistance,
                              ", Starting Levels: ", mStartingNumberOfLevels, ", Min Level Distance: ", mMinLevelPips);
                        return;
                    }

                    double totalLowerDistance = CurrentTick().Bid() - iLow(mEntrySymbol, mEntryTimeFrame, tempMBState.LowIndex());
                    int totalLowerLevels = 0;
                    double lowerLevelDistance = 0.0;
                    GetGridLevelsAndDistance(totalLowerDistance, totalLowerLevels, lowerLevelDistance);

                    if (totalLowerLevels == 0)
                    {
                        Print("No Lower Levels. Total Distance: ", totalLowerDistance, ", Upper Level Distance: ", lowerLevelDistance,
                              ", Starting Levels: ", mStartingNumberOfLevels, ", Min Level Distance: ", mMinLevelPips);
                        return;
                    }

                    mGT.ReInit(iOpen(mEntrySymbol, mEntryTimeFrame, 0),
                               totalUpperLevels,
                               totalLowerLevels,
                               upperLevelDistance,
                               lowerLevelDistance);

                    double potentialMaxLoss = 0;
                    double potentialMaxLossPips = 0;
                    for (int i = totalUpperLevels; i > 0; i--)
                    {
                        potentialMaxLoss += i;
                    }

                    potentialMaxLossPips = potentialMaxLoss * upperLevelDistance;

                    potentialMaxLoss = 0;
                    for (int i = totalLowerLevels; i > 0; i--)
                    {
                        potentialMaxLoss += i;
                    }

                    potentialMaxLossPips += potentialMaxLoss * lowerLevelDistance;

                    potentialMaxLossPips = OrderHelper::RangeToPips(totalUpperDistance + totalLowerDistance);
                    mLotSize = OrderHelper::GetLotSize(potentialMaxLossPips, RiskPercent()) / totalUpperLevels;
                    Print("Total levels: ", totalUpperLevels + totalLowerLevels, ", Potential Max Loss: ", potentialMaxLoss, ", Potential Max Loss Pips: ", potentialMaxLossPips);
                    mHasSetup = true;
                }
            }
        }
        else if (SetupType() == OP_SELL)
        {
            if (iHigh(mEntrySymbol, mEntryTimeFrame, 1) > iLow(mEntrySymbol, mEntryTimeFrame, tempMBState.LowIndex()))
            {
                if (CandleStickHelper::BrokeFurther(OP_SELL, mEntrySymbol, mEntryTimeFrame, 1))
                {
                    int currentRetracementIndex = EMPTY;
                    if (!mMBT.CurrentBearishRetracementIndexIsValid(currentRetracementIndex))
                    {
                        return;
                    }

                    double totalUpperDistance = iHigh(mEntrySymbol, mEntryTimeFrame, tempMBState.HighIndex()) - CurrentTick().Bid();
                    int totalUpperLevels = 0;
                    double upperLevelDistance = 0.0;
                    GetGridLevelsAndDistance(totalUpperDistance, totalUpperLevels, upperLevelDistance);

                    if (totalUpperLevels == 0)
                    {
                        Print("No Upper Levels. Total Distance: ", totalUpperDistance, ", Upper Level Distance: ", upperLevelDistance,
                              ", Starting Levels: ", mStartingNumberOfLevels, ", Min Level Distance: ", mMinLevelPips);
                        return;
                    }

                    double totalLowerDistance = CurrentTick().Bid() - iLow(mEntrySymbol, mEntryTimeFrame, currentRetracementIndex);
                    int totalLowerLevels = 0;
                    double lowerLevelDistance = 0.0;
                    GetGridLevelsAndDistance(totalLowerDistance, totalLowerLevels, lowerLevelDistance);

                    if (totalLowerLevels == 0)
                    {
                        Print("No Lower Levels. Total Distance: ", totalLowerDistance, ", Upper Level Distance: ", lowerLevelDistance,
                              ", Starting Levels: ", mStartingNumberOfLevels, ", Min Level Distance: ", mMinLevelPips);
                        return;
                    }

                    mGT.ReInit(iOpen(mEntrySymbol, mEntryTimeFrame, 0),
                               totalUpperLevels,
                               totalLowerLevels,
                               upperLevelDistance,
                               lowerLevelDistance);

                    double potentialMaxLoss = 0;
                    double potentialMaxLossPips = 0;
                    for (int i = totalUpperLevels; i > 0; i--)
                    {
                        potentialMaxLoss += i;
                    }

                    potentialMaxLossPips = potentialMaxLoss * upperLevelDistance;

                    potentialMaxLoss = 0;
                    for (int i = totalLowerLevels; i > 0; i--)
                    {
                        potentialMaxLoss += i;
                    }

                    potentialMaxLossPips += potentialMaxLoss * lowerLevelDistance;

                    potentialMaxLossPips = OrderHelper::RangeToPips(totalUpperDistance + totalLowerDistance);
                    mLotSize = OrderHelper::GetLotSize(potentialMaxLossPips, RiskPercent()) / totalLowerLevels;
                    mHasSetup = true;
                }
            }
        }
    }
}

void MBGridMultiplier::GetGridLevelsAndDistance(double totalDistance, int &levels, double &levelDistance)
{
    levelDistance = totalDistance / mStartingNumberOfLevels;
    levels = mStartingNumberOfLevels;
    double minLevelDistance = OrderHelper::PipsToRange(mMinLevelPips);

    while (levelDistance < minLevelDistance)
    {
        levels -= 1;
        if (levels == 0)
        {
            Print("Zero Levels. Total Distance: ", totalDistance, ", Min Level Distance: ", minLevelDistance, ", Starting Levels: ", mStartingNumberOfLevels);
            break;
        }

        levelDistance = totalDistance / levels;
    }
}

void MBGridMultiplier::CheckInvalidateSetup()
{
    mLastState = EAStates::CHECKING_FOR_INVALID_SETUP;

    if (mGT.AtMaxLevel())
    {
        // Print("Inv At Max Level");
        mCloseAllTickets = true;
    }

    if (mCloseAllTickets && mPreviousSetupTickets.Size() == 0)
    {
        InvalidateSetup(true);
    }
}

void MBGridMultiplier::InvalidateSetup(bool deletePendingOrder, int error = ERR_NO_ERROR)
{
    // Print("Reset");
    EAHelper::InvalidateSetup<MBGridMultiplier>(this, deletePendingOrder, mStopTrading, error);

    mFirstTrade = true;
    mPreviousAchievedLevel = 1000;
    mStartingEquity = 0;
    mCloseAllTickets = false;
    mLevelsWithTickets.Clear();
    mGT.Reset();
}

bool MBGridMultiplier::Confirmation()
{
    // going to close all tickets
    if (mGT.AtMaxLevel())
    {
        return false;
    }

    if ((SetupType() == OP_BUY && mGT.CurrentLevel() < 0) || (SetupType() == OP_SELL && mGT.CurrentLevel() > 0))
    {
        return false;
    }

    if (mGT.CurrentLevel() != mPreviousAchievedLevel && !mLevelsWithTickets.HasKey(mGT.CurrentLevel()))
    {
        mPreviousAchievedLevel = mGT.CurrentLevel();
        return true;
    }

    return false;
}

void MBGridMultiplier::PlaceOrders()
{
    double entry = 0.0;
    double stopLoss = 0.0;
    double takeProfit = 0.0;

    if (SetupType() == OP_BUY)
    {
        entry = CurrentTick().Ask();
        // don't want to place a tp on the last level because they we won't call ManagePreviousSetupTickets on it to check that we are at the last level
        takeProfit = mGT.AtMaxLevel() ? 0.0 : mGT.LevelPrice(mGT.CurrentLevel() + 1);
        stopLoss = mGT.LevelPrice(mGT.CurrentLevel() - 1);
    }
    else if (SetupType() == OP_SELL)
    {
        entry = CurrentTick().Bid();
        // don't want to place a tp on the last level because they we won't call ManagePreviousSetupTickets on it to check that we are at the last level
        takeProfit = mGT.AtMaxLevel() ? 0.0 : mGT.LevelPrice(mGT.CurrentLevel() - 1);
        stopLoss = mGT.LevelPrice(mGT.CurrentLevel() + 1);
    }

    if (mFirstTrade)
    {
        mStartingEquity = AccountBalance();
        mFirstTrade = false;
    }

    EAHelper::PlaceMarketOrder<MBGridMultiplier>(this, entry, stopLoss, mLotSize, SetupType(), takeProfit);
    if (mCurrentSetupTicket.Number() != EMPTY)
    {
        mLevelsWithTickets.Add(mGT.CurrentLevel(), mCurrentSetupTicket.Number());
    }
}

void MBGridMultiplier::ManageCurrentPendingSetupTicket()
{
}

void MBGridMultiplier::ManageCurrentActiveSetupTicket()
{
}

bool MBGridMultiplier::MoveToPreviousSetupTickets(Ticket &ticket)
{
    return true;
}

void MBGridMultiplier::ManagePreviousSetupTicket(int ticketIndex)
{
    if (mCloseAllTickets)
    {
        mPreviousSetupTickets[ticketIndex].Close();
        return;
    }

    // double equityPercentChange = EAHelper::GetTotalPreviousSetupTicketsEquityPercentChange<MBGridMultiplier>(this, mStartingEquity);
    // if (equityPercentChange <= -0.3)
    // {
    //     Print("Equity Limit Reached: ", equityPercentChange);
    //     mCloseAllTickets = true;
    //     mPreviousSetupTickets[ticketIndex].Close();

    //     return;
    // }
}

void MBGridMultiplier::CheckCurrentSetupTicket()
{
    EAHelper::CheckUpdateHowFarPriceRanFromOpen<MBGridMultiplier>(this, mCurrentSetupTicket);
    EAHelper::CheckCurrentSetupTicket<MBGridMultiplier>(this);
}

void MBGridMultiplier::CheckPreviousSetupTicket(int ticketIndex)
{
    bool isClosed = false;
    mPreviousSetupTickets[ticketIndex].IsClosed(isClosed);
    if (isClosed)
    {
        mLevelsWithTickets.RemoveByValue(mPreviousSetupTickets[ticketIndex].Number());
    }

    EAHelper::CheckUpdateHowFarPriceRanFromOpen<MBGridMultiplier>(this, mPreviousSetupTickets[ticketIndex]);
    EAHelper::CheckPreviousSetupTicket<MBGridMultiplier>(this, ticketIndex);
}

void MBGridMultiplier::RecordTicketOpenData()
{
    EAHelper::RecordSingleTimeFrameEntryTradeRecord<MBGridMultiplier>(this);
}

void MBGridMultiplier::RecordTicketPartialData(Ticket &partialedTicket, int newTicketNumber)
{
    EAHelper::RecordPartialTradeRecord<MBGridMultiplier>(this, partialedTicket, newTicketNumber);
}

void MBGridMultiplier::RecordTicketCloseData(Ticket &ticket)
{
    EAHelper::RecordSingleTimeFrameExitTradeRecord<MBGridMultiplier>(this, ticket, Period());
}

void MBGridMultiplier::RecordError(int error, string additionalInformation = "")
{
    EAHelper::RecordSingleTimeFrameErrorRecord<MBGridMultiplier>(this, error, additionalInformation);
}

bool MBGridMultiplier::ShouldReset()
{
    return !EAHelper::WithinTradingSession<MBGridMultiplier>(this);
}

void MBGridMultiplier::Reset()
{
}