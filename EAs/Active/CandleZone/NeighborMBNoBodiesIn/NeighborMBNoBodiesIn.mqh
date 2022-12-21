//+------------------------------------------------------------------+
//|                                        CandleZone.mqh |
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

class CandleZone : public EA<SingleTimeFrameEntryTradeRecord, PartialTradeRecord, SingleTimeFrameExitTradeRecord, SingleTimeFrameErrorRecord>
{
public:
    MBTracker *mSetupMBT;
    int mFirstMBInSetupNumber;

    string mEntrySymbol;
    int mEntryTimeFrame;

    int mBarCount;
    int mLastEntryMB;

    datetime mZoneCandleTime;
    datetime mEntryCandleTime;

    double mEntryPaddingPips;
    double mMinStopLossPips;
    double mPipsToWaitBeforeBE;
    double mBEAdditionalPips;

public:
    CandleZone(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
               CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
               CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter, MBTracker *&setupMBT);
    ~CandleZone();

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

CandleZone::CandleZone(int magicNumber, int setupType, int maxCurrentSetupTradesAtOnce, int maxTradesPerDay, double stopLossPaddingPips, double maxSpreadPips, double riskPercent,
                       CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *&entryCSVRecordWriter, CSVRecordWriter<SingleTimeFrameExitTradeRecord> *&exitCSVRecordWriter,
                       CSVRecordWriter<SingleTimeFrameErrorRecord> *&errorCSVRecordWriter, MBTracker *&setupMBT)
    : EA(magicNumber, setupType, maxCurrentSetupTradesAtOnce, maxTradesPerDay, stopLossPaddingPips, maxSpreadPips, riskPercent, entryCSVRecordWriter, exitCSVRecordWriter, errorCSVRecordWriter)
{
    mSetupMBT = setupMBT;
    mFirstMBInSetupNumber = EMPTY;

    mEntrySymbol = Symbol();
    mEntryTimeFrame = Period();

    mBarCount = 0;
    mLastEntryMB = EMPTY;

    mZoneCandleTime = 0;
    mEntryCandleTime = 0;

    mEntryPaddingPips = 0.0;
    mMinStopLossPips = 0.0;
    mPipsToWaitBeforeBE = 0.0;
    mBEAdditionalPips = 0.0;

    mLargestAccountBalance = 100000;

    EAHelper::FindSetPreviousAndCurrentSetupTickets<CandleZone>(this);
    EAHelper::UpdatePreviousSetupTicketsRRAcquried<CandleZone, PartialTradeRecord>(this);
    EAHelper::SetPreviousSetupTicketsOpenData<CandleZone, SingleTimeFrameEntryTradeRecord>(this);
}

CandleZone::~CandleZone()
{
}

void CandleZone::Run()
{
    EAHelper::RunDrawMBT<CandleZone>(this, mSetupMBT);
    mBarCount = iBars(mEntrySymbol, mEntryTimeFrame);
}

bool CandleZone::AllowedToTrade()
{
    return EAHelper::BelowSpread<CandleZone>(this) && EAHelper::WithinTradingSession<CandleZone>(this);
}

void CandleZone::CheckSetSetup()
{
    if (iBars(mEntrySymbol, mEntryTimeFrame) <= mBarCount)
    {
        return;
    }

    if (mSetupMBT.MBsCreated() - 1 == mLastEntryMB)
    {
        return;
    }

    if (EAHelper::CheckSetSingleMBSetup<CandleZone>(this, mSetupMBT, mFirstMBInSetupNumber, mSetupType))
    {
        MBState *firstMBInSetup;
        if (!mSetupMBT.GetMB(mFirstMBInSetupNumber, firstMBInSetup))
        {
            return;
        }

        // make sure first mb isn't too small
        if (firstMBInSetup.StartIndex() - firstMBInSetup.EndIndex() < 10)
        {
            return;
        }

        int pendingMBStart = EMPTY;
        double pendingMBHeight = 0.0;
        if (EAHelper::MostRecentMBZoneIsHolding<CandleZone>(this, mSetupMBT, mFirstMBInSetupNumber))
        {
            if (mSetupType == OP_BUY)
            {
                if (!mSetupMBT.CurrentBullishRetracementIndexIsValid(pendingMBStart))
                {
                    return;
                }

                if (firstMBInSetup.EndIndex() - pendingMBStart > 2)
                {
                    return;
                }

                int lowestIndex = EMPTY;
                if (!MQLHelper::GetLowestIndexBetween(mEntrySymbol, mEntryTimeFrame, firstMBInSetup.EndIndex() - 1, 1, true, lowestIndex))
                {
                    return;
                }

                // need to break within 3 candles of our lowest
                if (lowestIndex > 3)
                {
                    return;
                }

                // make sure we broke above
                if (iClose(mEntrySymbol, mEntryTimeFrame, 1) < iHigh(mEntrySymbol, mEntryTimeFrame, 2))
                {
                    return;
                }

                mHasSetup = true;
                mZoneCandleTime = iTime(mEntrySymbol, mEntryTimeFrame, 2);
            }
            else if (mSetupType == OP_SELL)
            {
                if (!mSetupMBT.CurrentBearishRetracementIndexIsValid(pendingMBStart))
                {
                    return;
                }

                if (firstMBInSetup.EndIndex() - pendingMBStart > 2)
                {
                    return;
                }

                int highestIndex = EMPTY;
                if (!MQLHelper::GetHighestIndexBetween(mEntrySymbol, mEntryTimeFrame, firstMBInSetup.EndIndex() - 1, 1, true, highestIndex))
                {
                    return;
                }

                // need to break within 3 candles of our highest
                if (highestIndex > 3)
                {
                    return;
                }

                // make sure we broke below a candle
                if (iClose(mEntrySymbol, mEntryTimeFrame, 1) > iLow(mEntrySymbol, mEntryTimeFrame, 2))
                {
                    return;
                }

                mHasSetup = true;
                mZoneCandleTime = iTime(mEntrySymbol, mEntryTimeFrame, 2);
            }
        }
    }
}

void CandleZone::CheckInvalidateSetup()
{
    mLastState = EAStates::CHECKING_FOR_INVALID_SETUP;

    if (iBars(mEntrySymbol, mEntryTimeFrame) <= mBarCount)
    {
        return;
    }

    if (mFirstMBInSetupNumber != mSetupMBT.MBsCreated() - 1)
    {
        InvalidateSetup(true);
        return;
    }

    if (!mHasSetup)
    {
        return;
    }

    if (!EAHelper::MostRecentMBZoneIsHolding<CandleZone>(this, mSetupMBT, mFirstMBInSetupNumber))
    {
        InvalidateSetup(true);
        return;
    }

    int zoneCandleIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mZoneCandleTime);
    if (mSetupType == OP_BUY)
    {
        // invalidate if we broke below our candle zone with a body
        if (iLow(mEntrySymbol, mEntryTimeFrame, 1) < iLow(mEntrySymbol, mEntryTimeFrame, zoneCandleIndex))
        {
            InvalidateSetup(true);
            return;
        }
    }
    else if (mSetupType == OP_SELL)
    {
        // invalidate if we broke above our candle zone with a body
        if (iHigh(mEntrySymbol, mEntryTimeFrame, 1) > iHigh(mEntrySymbol, mEntryTimeFrame, zoneCandleIndex))
        {
            InvalidateSetup(true);
            return;
        }
    }
}

void CandleZone::InvalidateSetup(bool deletePendingOrder, int error = ERR_NO_ERROR)
{
    EAHelper::InvalidateSetup<CandleZone>(this, deletePendingOrder, false, error);

    mFirstMBInSetupNumber = EMPTY;
    mZoneCandleTime = 0;
}

bool CandleZone::Confirmation()
{
    bool hasTicket = mCurrentSetupTicket.Number() != EMPTY;

    if (iBars(mEntrySymbol, mEntryTimeFrame) <= mBarCount)
    {
        return hasTicket;
    }

    int zoneCandleIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mZoneCandleTime);

    // make sure we actually had a decent push up after the inital break
    if (zoneCandleIndex < 5)
    {
        return false;
    }

    int pushedBackTowardsZoneValidIndex = EMPTY;
    int firstCandleInZone = EMPTY;
    double zoneEntry = 0.0;
    if (mSetupType == OP_BUY)
    {
        zoneEntry = iHigh(mEntrySymbol, mEntryTimeFrame, zoneCandleIndex);
        if (iLow(mEntrySymbol, mEntryTimeFrame, 2) > zoneEntry)
        {
            return false;
        }

        for (int i = zoneCandleIndex - 1; i >= 1; i--)
        {
            // need to have a bearish candle break a previuos one, heading back into the candle zone in order for it to be considered a
            // decent push back in
            if (CandleStickHelper::IsBearish(mEntrySymbol, mEntryTimeFrame, i) &&
                MathMin(iOpen(mEntrySymbol, mEntryTimeFrame, i), iClose(mEntrySymbol, mEntryTimeFrame, i)) < iLow(mEntrySymbol, mEntryTimeFrame, i + 1))
            {
                pushedBackTowardsZoneValidIndex = i;
                break;
            }
        }

        if (pushedBackTowardsZoneValidIndex == EMPTY)
        {
            return false;
        }

        for (int i = pushedBackTowardsZoneValidIndex; i >= 1; i--)
        {
            if (iLow(mEntrySymbol, mEntryTimeFrame, i) <= zoneEntry)
            {
                firstCandleInZone = i;
                break;
            }
        }

        if (firstCandleInZone == EMPTY || firstCandleInZone > 2)
        {
            return false;
        }

        // need to have 2 wicks in the zone but no bodies
        if (iLow(mEntrySymbol, mEntryTimeFrame, 2) <= zoneEntry &&
            CandleStickHelper::LowestBodyPart(mEntrySymbol, mEntryTimeFrame, 2) > zoneEntry &&
            iLow(mEntrySymbol, mEntryTimeFrame, 1) <= zoneEntry &&
            CandleStickHelper::LowestBodyPart(mEntrySymbol, mEntryTimeFrame, 1) > zoneEntry)
        {
            return true;
        }
    }
    else if (mSetupType == OP_SELL)
    {
        zoneEntry = iLow(mEntrySymbol, mEntryTimeFrame, zoneCandleIndex);
        if (iHigh(mEntrySymbol, mEntryTimeFrame, 2) < zoneEntry)
        {
            return false;
        }

        for (int i = zoneCandleIndex - 1; i >= 1; i--)
        {
            // need to have a bullish candle break a previuos one, heading back into the candle zone in order for it to be considered a
            // decent push back in
            if (CandleStickHelper::IsBullish(mEntrySymbol, mEntryTimeFrame, i) &&
                MathMax(iOpen(mEntrySymbol, mEntryTimeFrame, i), iClose(mEntrySymbol, mEntryTimeFrame, i)) > iHigh(mEntrySymbol, mEntryTimeFrame, i + 1))
            {
                pushedBackTowardsZoneValidIndex = i;
                break;
            }
        }

        if (pushedBackTowardsZoneValidIndex == EMPTY)
        {
            return false;
        }

        for (int i = pushedBackTowardsZoneValidIndex; i >= 1; i--)
        {
            if (iHigh(mEntrySymbol, mEntryTimeFrame, i) >= zoneEntry)
            {
                firstCandleInZone = i;
                break;
            }
        }

        if (firstCandleInZone == EMPTY || firstCandleInZone > 2)
        {
            return false;
        }

        // need to have 2 wicks in the zone but no bodies
        if (iHigh(mEntrySymbol, mEntryTimeFrame, 2) >= zoneEntry &&
            CandleStickHelper::HighestBodyPart(mEntrySymbol, mEntryTimeFrame, 2) < zoneEntry &&
            iHigh(mEntrySymbol, mEntryTimeFrame, 1) >= zoneEntry &&
            CandleStickHelper::HighestBodyPart(mEntrySymbol, mEntryTimeFrame, 1) < zoneEntry)
        {
            return true;
        }
    }

    return hasTicket;
}

void CandleZone::PlaceOrders()
{
    if (mCurrentSetupTicket.Number() != EMPTY)
    {
        return;
    }

    MqlTick currentTick;
    if (!SymbolInfoTick(Symbol(), currentTick))
    {
        RecordError(GetLastError());
        return;
    }

    double entry = 0.0;
    double stopLoss = 0.0;

    if (mSetupType == OP_BUY)
    {
        double lowest = MathMin(iLow(mEntrySymbol, mEntryTimeFrame, 2), iLow(mEntrySymbol, mEntryTimeFrame, 1));

        entry = iHigh(mEntrySymbol, mEntryTimeFrame, 1) + OrderHelper::PipsToRange(mMaxSpreadPips + mEntryPaddingPips);
        stopLoss = lowest - OrderHelper::PipsToRange(mStopLossPaddingPips);
    }
    else if (mSetupType == OP_SELL)
    {
        double highest = MathMax(iHigh(mEntrySymbol, mEntryTimeFrame, 2), iHigh(mEntrySymbol, mEntryTimeFrame, 1));

        entry = iLow(mEntrySymbol, mEntryTimeFrame, 1) - OrderHelper::PipsToRange(mEntryPaddingPips);
        stopLoss = highest + OrderHelper::PipsToRange(mStopLossPaddingPips + mMaxSpreadPips);
    }

    EAHelper::PlaceStopOrder<CandleZone>(this, entry, stopLoss, 0.0, true, mBEAdditionalPips);

    if (mCurrentSetupTicket.Number() != EMPTY)
    {
        mEntryCandleTime = iTime(mEntrySymbol, mEntryTimeFrame, 1);
    }
}

void CandleZone::ManageCurrentPendingSetupTicket()
{
    int entryCandleIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mEntryCandleTime);
    if (mCurrentSetupTicket.Number() == EMPTY)
    {
        return;
    }

    if (entryCandleIndex > 1)
    {
        InvalidateSetup(true);
    }
}

void CandleZone::ManageCurrentActiveSetupTicket()
{
    if (mLastEntryMB != mFirstMBInSetupNumber && mFirstMBInSetupNumber != EMPTY)
    {
        mLastEntryMB = mFirstMBInSetupNumber;
    }

    if (mCurrentSetupTicket.Number() == EMPTY)
    {
        return;
    }

    int selectError = mCurrentSetupTicket.SelectIfOpen("Stuff");
    if (TerminalErrors::IsTerminalError(selectError))
    {
        RecordError(selectError);
        return;
    }

    MqlTick currentTick;
    if (!SymbolInfoTick(Symbol(), currentTick))
    {
        RecordError(GetLastError());
        return;
    }

    if (EAHelper::CloseIfPercentIntoStopLoss<CandleZone>(this, mCurrentSetupTicket, 0.5))
    {
        return;
    }

    int entryIndex = iBarShift(mEntrySymbol, mEntryTimeFrame, mEntryCandleTime);
    bool movedPips = false;

    if (mSetupType == OP_BUY)
    {
        movedPips = currentTick.bid - OrderOpenPrice() >= OrderHelper::PipsToRange(mPipsToWaitBeforeBE);
    }
    else if (mSetupType == OP_SELL)
    {
        movedPips = OrderOpenPrice() - currentTick.ask >= OrderHelper::PipsToRange(mPipsToWaitBeforeBE);
    }

    if (movedPips)
    {
        EAHelper::MoveToBreakEvenAsSoonAsPossible<CandleZone>(this, 1);
    }
}

bool CandleZone::MoveToPreviousSetupTickets(Ticket &ticket)
{
    return EAHelper::TicketStopLossIsMovedToBreakEven<CandleZone>(this, ticket);
}

void CandleZone::ManagePreviousSetupTicket(int ticketIndex)
{
    EAHelper::CheckPartialTicket<CandleZone>(this, mPreviousSetupTickets[ticketIndex]);
}

void CandleZone::CheckCurrentSetupTicket()
{
    EAHelper::CheckCurrentSetupTicket<CandleZone>(this);
}

void CandleZone::CheckPreviousSetupTicket(int ticketIndex)
{
    EAHelper::CheckPreviousSetupTicket<CandleZone>(this, ticketIndex);
}

void CandleZone::RecordTicketOpenData()
{
    EAHelper::RecordSingleTimeFrameEntryTradeRecord<CandleZone>(this);
}

void CandleZone::RecordTicketPartialData(Ticket &partialedTicket, int newTicketNumber)
{
    EAHelper::RecordPartialTradeRecord<CandleZone>(this, partialedTicket, newTicketNumber);
}

void CandleZone::RecordTicketCloseData(Ticket &ticket)
{
    EAHelper::RecordSingleTimeFrameExitTradeRecord<CandleZone>(this, ticket, mEntryTimeFrame);
}

void CandleZone::RecordError(int error, string additionalInformation = "")
{
    EAHelper::RecordSingleTimeFrameErrorRecord<CandleZone>(this, error, additionalInformation);
}

void CandleZone::Reset()
{
}