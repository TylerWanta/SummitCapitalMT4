//+------------------------------------------------------------------+
//|                                               TheGrannySmith.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.01"
#property strict

#include <Wantanites/EAs/Inactive/MB/BigDipper/BigDipper.mqh>
#include <Wantanites/Framework/Objects/Indicators/MB/EASetup.mqh>

string ForcedSymbol = "USDJPY";
int ForcedTimeFrame = 5;

// --- EA Inputs ---
double RiskPercent = 1;
int MaxCurrentSetupTradesAtOnce = 1;
int MaxTradesPerDay = 5;

string StrategyName = "BigDipper/";
string EAName = "";
string SetupTypeName = "";
string Directory = StrategyName + EAName + SetupTypeName;

CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *EntryWriter = new CSVRecordWriter<SingleTimeFrameEntryTradeRecord>(Directory + "Entries/", "Entries.csv");
CSVRecordWriter<PartialTradeRecord> *PartialWriter = new CSVRecordWriter<PartialTradeRecord>(Directory + "Partials/", "Partials.csv");
CSVRecordWriter<SingleTimeFrameExitTradeRecord> *ExitWriter = new CSVRecordWriter<SingleTimeFrameExitTradeRecord>(Directory + "Exits/", "Exits.csv");
CSVRecordWriter<SingleTimeFrameErrorRecord> *ErrorWriter = new CSVRecordWriter<SingleTimeFrameErrorRecord>(Directory + "Errors/", "Errors.csv");

CandleStickTracker *CST;

TradingSession *TS;

BigDipper *BuyEA;
BigDipper *SellEA;

// UJ
double MaxSpreadPips = 3;
double StopLossPaddingPips = 0;
double MaxSlippage = 3;
double CloseRR = 3;

int OnInit()
{
    TS = new TradingSession();
    TS.AddHourMinuteSession(2, 0, 23, 0);

    CST = new CandleStickTracker();

    BuyEA = new BigDipper(-1, SignalType::Bullish, MaxCurrentSetupTradesAtOnce, MaxTradesPerDay, StopLossPaddingPips,
                          MaxSpreadPips, RiskPercent, EntryWriter, ExitWriter, ErrorWriter, MBT, CST);

    BuyEA.AddPartial(CloseRR, 100);
    BuyEA.AddTradingSession(TS);
    BuyEA.SetPartialCSVRecordWriter(PartialWriter);

    SellEA = new BigDipper(-2, SignalType::Bearish, MaxCurrentSetupTradesAtOnce, MaxTradesPerDay, StopLossPaddingPips,
                           MaxSpreadPips, RiskPercent, EntryWriter, ExitWriter, ErrorWriter, MBT, CST);

    SellEA.AddPartial(CloseRR, 100);
    SellEA.AddTradingSession(TS);
    SellEA.SetPartialCSVRecordWriter(PartialWriter);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    delete MBT;
    delete CST;

    delete BuyEA;
    delete SellEA;

    delete EntryWriter;
    delete PartialWriter;
    delete ExitWriter;
    delete ErrorWriter;
}

void OnTick()
{
    BuyEA.Run();
    SellEA.Run();
}