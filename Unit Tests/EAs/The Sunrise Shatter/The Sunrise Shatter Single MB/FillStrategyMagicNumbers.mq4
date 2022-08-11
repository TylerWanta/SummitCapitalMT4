//+------------------------------------------------------------------+
//|                                     FillStrategyMagicNumbers.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <SummitCapital\EAs\The Sunrise Shatter\TheSunriseShatterSingleMB.mqh>
#include <SummitCapital\EAs\The Sunrise Shatter\TheSunriseShatterDoubleMB.mqh>
#include <SummitCapital\EAs\The Sunrise Shatter\TheSunriseShatterLiquidationMB.mqh>

#include <SummitCapital\Framework\Constants\Index.mqh>

#include <SummitCapital\Framework\Trackers\MBTracker.mqh>
#include <SummitCapital\Framework\Objects\MinROCFromTimeStamp.mqh>

#include <SummitCapital\Framework\Helpers\SetupHelper.mqh>
#include <SummitCapital\Framework\UnitTests\IntUnitTest.mqh>
#include <SummitCapital\Framework\UnitTests\BoolUnitTest.mqh>

#include <SummitCapital\Framework\CSVWriting\CSVRecordTypes\DefaultUnitTestRecord.mqh>

const string Directory = "/UnitTests/EAs/The Sunrise Shatter/The Sunrise Shatter Single MB/BreakAfterMinROC/";
const int NumberOfAsserts = 1;
const int AssertCooldown = 1;
const bool RecordScreenShot = false;
const bool RecordErrors = true;

MBTracker *MBT;
input int MBsToTrack = 3;
input int MaxZonesInMB = 5;
input bool AllowMitigatedZones = false;
input bool AllowZonesAfterMBValidation = true;
input bool PrintErrors = false;
input bool CalculateOnTick = true;

MinROCFromTimeStamp *MRFTS;
input int ServerHourStartTime = 16;
input int ServerMinuteStartTime = 30;
input int ServerHourEndTime = 16;
input int ServerMinuteEndTime = 33;
input double MinROCPercent = 0.18;

TheSunriseShatterSingleMB *TSSSMB;
const int MaxTradesPerStrategy = 1;
const int StopLossPaddingPips = 0;
const int MaxSpreadPips = 70;
const double RiskPercent = 0.25;

BoolUnitTest<DefaultUnitTestRecord> *FillStrategyMagicNumbersUnitTest;

int OnInit()
{
    MBT = new MBTracker(MBsToTrack, MaxZonesInMB, AllowMitigatedZones, AllowZonesAfterMBValidation, PrintErrors, CalculateOnTick);
    MRFTS = new MinROCFromTimeStamp(Symbol(), Period(), ServerHourStartTime, ServerHourEndTime, ServerMinuteStartTime, ServerMinuteEndTime, MinROCPercent);
    TSSSMB = new TheSunriseShatterSingleMB(MaxTradesPerStrategy, StopLossPaddingPips, MaxSpreadPips, RiskPercent, MRFTS, MBT);

    FillStrategyMagicNumbersUnitTest = new BoolUnitTest<DefaultUnitTestRecord>(
        Directory, "Fill Strategy Magic Numbers", "Returns True If The Strategy Magic Numbers Array Was Correctly Filled",
        NumberOfAsserts, AssertCooldown, RecordScreenShot, RecordErrors,
        true, FillStrategyMagicNumbers);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    delete MBT;
    delete MRFTS;
    delete TSSSMB;
}

void OnTick()
{
    FillStrategyMagicNumbersUnitTest.Assert();
}

int FillStrategyMagicNumbers(bool &actual)
{
    int strategyMagicNumbers[];
    ArrayResize(strategyMagicNumbers, 3);

    TSSSMB.StrategyMagicNumbers(strategyMagicNumbers);
    actual = strategyMagicNumbers[0] == TheSunriseShatterSingleMB::MagicNumber &&
             strategyMagicNumbers[1] == TheSunriseShatterDoubleMB::MagicNumber &&
             strategyMagicNumbers[2] == TheSunriseShatterLiquidationMB::MagicNumber;

    return Results::UNIT_TEST_RAN;
}