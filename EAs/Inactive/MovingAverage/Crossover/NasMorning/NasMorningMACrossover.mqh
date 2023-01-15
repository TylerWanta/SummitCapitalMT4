//+------------------------------------------------------------------+
//|                                                    NasMorningBreak.mqh |
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

class NasMorningBreak : public EA<SingleTimeFrameEntryTradeRecord, PartialTradeRecord, SingleTimeFrameExitTradeRecord, SingleTimeFrameErrorRecord>
{
public:
    datetime mLastFractalTime;

    int mEntryTimeFrame;
    string mEntrySymbol;

    int mBarCount;
    int mLastDay;

    int mCloseHour;
    int mCloseMinute;

    double mEntryPaddingPips;
    double mMinStopLossPips;
    double mPipsToWaitBeforeBE;
    double mBEAdditionalPips;

    datetime mEntryCandleTime;

public:
    NasMorningBreak(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
                    CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
                    CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter);
    ~NasMorningBreak();

    virtual double RiskPercent() { return mRiskPercent; }

    virtual void Run();
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
    virtual void Reset();
};

NasMorningBreak::NasMorningBreak(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
                                 CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
                                 CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter)
    : EA(magicNumber, setupType, maxCurrentSetupTradesAtOnce, maxTradesPerDay, stopLossPaddingPips, maxSpreadPips, riskPercent, entryCSVRecordWriter, exitCSVRecordWriter, errorCSVRecordWriter)
{
    mLastFractalTime = 0;

    mEntrySymbol = Symbol();
    mEntryTimeFrame = Period();

    mBarCount = 0;
    mLastDay = Day();

    mCloseHour = 0;
    mCloseMinute = 0;

    mEntryPaddingPips = 0.0;
    mMinStopLossPips = 0.0;
    mPipsToWaitBeforeBE = 0.0;
    mBEAdditionalPips = 0.0;

    mEntryCandleTime = 0;

    mLargestAccountBalance = 200000;

    EAHelper::FindSetPreviousAndCurrentSetupTickets<NasMorningBreak>(this);
    EAHelper::UpdatePreviousSetupTicketsRRAcquried<NasMorningBreak, PartialTradeRecord>(this);
    EAHelper::SetPreviousSetupTicketsOpenData<NasMorningBreak, SingleTimeFrameEntryTradeRecord>(this);
}

NasMorningBreak::~NasMorningBreak()
{
}

void NasMorningBreak::Run()
{
    EAHelper::Run<NasMorningBreak>(this);

    mBarCount = iBars(mEntrySymbol, mEntryTimeFrame);
    mLastDay = Day();
}

bool NasMorningBreak::AllowedToTrade()
{
    return EAHelper::BelowSpread<NasMorningBreak>(this) && EAHelper::WithinTradingSession<NasMorningBreak>(this);
}

void NasMorningBreak::CheckSetSetup()
{
    double currentFractal = 0.0;
    double furthestBetweenFractal = 0.0;

    if (mSetupType == OP_BUY)
    {
        // go back to 3 so that we only consider fractals that are already created and not potential fractals based on our current candle
        for (int i = 3; i <= 15; i++)
        {
            currentFractal = iFractals(mEntrySymbol, mEntryTimeFrame, MODE_UPPER, i);
            if (currentFractal > 0)
            {
                if (!MQLHelper::GetHighestHighBetween(mEntrySymbol, mEntryTimeFrame, i, 1, false, furthestBetweenFractal))
                {
                    return;
                }

                if (furthestBetweenFractal < iHigh(mEntrySymbol, mEntryTimeFrame, i))
                {
                    mLastFractalTime = iTime(mEntrySymbol, mEntryTimeFrame, i);
                    mHasSetup = true;
                }
                else
                {
                    mStopTrading = true;
                }

                break;
            }
        }
    }
    else if (mSetupType == OP_SELL)
    {
        // go back to 3 so that we only consider fractals that are already created and not potential fractals based on our current candle
        for (int i = 3; i <= 15; i++)
        {
            currentFractal = iFractals(mEntrySymbol, mEntryTimeFrame, MODE_LOWER, i);
            if (currentFractal > 0)
            {
                if (!MQLHelper::GetLowestLowBetween(mEntrySymbol, mEntryTimeFrame, i, 1, false, furthestBetweenFractal))
                {
                    return;
                }

                if (furthestBetweenFractal > iLow(mEntrySymbol, mEntryTimeFrame, i))
                {
                    mLastFractalTime = iTime(mEntrySymbol, mEntryTimeFrame, i);
                    mHasSetup = true;
                }
                else
                {
                    mStopTrading = true;
                }

                break;
            }
        }
    }
}

void NasMorningBreak::CheckInvalidateSetup()
{
    mLastState = EAStates::CHECKING_FOR_INVALID_SETUP;

    if (mLastDay != Day())
    {
        InvalidateSetup(true);
    }
}

void NasMorningBreak::InvalidateSetup(bool deletePendingOrder, int error = ERR_NO_ERROR)
{
    EAHelper::InvalidateSetup<NasMorningBreak>(this, deletePendingOrder, mStopTrading, error);
    mLastFractalTime = 0;
}

bool NasMorningBreak::Confirmation()
{
    return true;
}

void NasMorningBreak::PlaceOrders()
{
    MqlTick currentTick;
    if (!SymbolInfoTick(Symbol(), currentTick))
    {
        RecordError(GetLastError());
        return;
    }

    if (mLastFractalTime <= 0)
    {
        return;
    }

    int lastFractalIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mLastFractalTime);

    double entry = 0.0;
    double stopLoss = 0.0;

    if (mSetupType == OP_BUY)
    {
        entry = iHigh(mEntrySymbol, mEntryTimeFrame, lastFractalIndex) + OrderHelper::PipsToRange(mMaxSpreadPips);

        if (!MQLHelper::GetLowestLowBetween(mEntrySymbol, mEntryTimeFrame, lastFractalIndex, 0, true, stopLoss))
        {
            return;
        }

        stopLoss = MathMin(stopLoss, entry - OrderHelper::PipsToRange(mMinStopLossPips));
    }
    else if (mSetupType == OP_SELL)
    {
        entry = iLow(mEntrySymbol, mEntryTimeFrame, lastFractalIndex);

        if (!MQLHelper::GetHighestHighBetween(mEntrySymbol, mEntryTimeFrame, lastFractalIndex, 0, true, stopLoss))
        {
            return;
        }

        stopLoss += OrderHelper::PipsToRange(mMaxSpreadPips);
        stopLoss = MathMax(stopLoss, entry + OrderHelper::PipsToRange(mMinStopLossPips));
    }

    EAHelper::PlaceStopOrder<NasMorningBreak>(this, entry, stopLoss, 0.0, true, mBEAdditionalPips);
    mStopTrading = true;
}

void NasMorningBreak::ManageCurrentPendingSetupTicket()
{
}

void NasMorningBreak::ManageCurrentActiveSetupTicket()
{
    int openIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mCurrentSetupTicket.OpenTime());
    if (openIndex >= 1)
    {
        mCurrentSetupTicket.Close();
    }

    EAHelper::MoveToBreakEvenAfterPips<NasMorningBreak>(this, mCurrentSetupTicket, mPipsToWaitBeforeBE, mBEAdditionalPips);
}

bool NasMorningBreak::MoveToPreviousSetupTickets(Ticket &ticket)
{
    return EAHelper::TicketStopLossIsMovedToBreakEven<NasMorningBreak>(this, ticket);
}

void NasMorningBreak::ManagePreviousSetupTicket(int ticketIndex)
{
    // EAHelper::CloseTicketIfPastTime<NasMorningBreak>(this, mPreviousSetupTickets[ticketIndex], mCloseHour, mCloseMinute);
    int openIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mPreviousSetupTickets[ticketIndex].OpenTime());
    if (openIndex >= 1)
    {
        mPreviousSetupTickets[ticketIndex].Close();
    }
}

void NasMorningBreak::CheckCurrentSetupTicket()
{
    EAHelper::CheckUpdateHowFarPriceRanFromOpen<NasMorningBreak>(this, mCurrentSetupTicket);
    EAHelper::CheckCurrentSetupTicket<NasMorningBreak>(this);
}

void NasMorningBreak::CheckPreviousSetupTicket(int ticketIndex)
{
    EAHelper::CheckUpdateHowFarPriceRanFromOpen<NasMorningBreak>(this, mPreviousSetupTickets[ticketIndex]);
    EAHelper::CheckPreviousSetupTicket<NasMorningBreak>(this, ticketIndex);
}

void NasMorningBreak::RecordTicketOpenData()
{
    EAHelper::RecordSingleTimeFrameEntryTradeRecord<NasMorningBreak>(this);
}

void NasMorningBreak::RecordTicketPartialData(Ticket &partialedTicket, int newTicketNumber)
{
    EAHelper::RecordPartialTradeRecord<NasMorningBreak>(this, partialedTicket, newTicketNumber);
}

void NasMorningBreak::RecordTicketCloseData(Ticket &ticket)
{
    EAHelper::RecordSingleTimeFrameExitTradeRecord<NasMorningBreak>(this, ticket, Period());
}

void NasMorningBreak::RecordError(int error, string additionalInformation = "")
{
    EAHelper::RecordSingleTimeFrameErrorRecord<NasMorningBreak>(this, error, additionalInformation);
}

void NasMorningBreak::Reset()
{
    mStopTrading = false;
    InvalidateSetup(true);
}