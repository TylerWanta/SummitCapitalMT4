//+------------------------------------------------------------------+
//|                                               TheGrannySmith.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <SummitCapital/Framework/Constants/MagicNumbers.mqh>
#include <SummitCapital/Framework/Constants/SymbolConstants.mqh>
#include <SummitCapital/EAs/Inactive/PriceRange/PriceRange.mqh>

string ForcedSymbol = "US100";
int ForcedTimeFrame = 5;

// --- EA Inputs ---
double RiskPercent = 1;
int MaxCurrentSetupTradesAtOnce = 1;
int MaxTradesPerDay = 5;

string StrategyName = "PriceRange/";
string EAName = "Nas/";
string SetupTypeName = "";
string Directory = StrategyName + EAName + SetupTypeName;

CSVRecordWriter<SingleTimeFrameEntryTradeRecord> *EntryWriter = new CSVRecordWriter<SingleTimeFrameEntryTradeRecord>(Directory + "Entries/", "Entries.csv");
CSVRecordWriter<PartialTradeRecord> *PartialWriter = new CSVRecordWriter<PartialTradeRecord>(Directory + "Partials/", "Partials.csv");
CSVRecordWriter<SingleTimeFrameExitTradeRecord> *ExitWriter = new CSVRecordWriter<SingleTimeFrameExitTradeRecord>(Directory + "Exits/", "Exits.csv");
CSVRecordWriter<SingleTimeFrameErrorRecord> *ErrorWriter = new CSVRecordWriter<SingleTimeFrameErrorRecord>(Directory + "Errors/", "Errors.csv");

PriceRange *PRBuys;
PriceRange *PRSells;

// Nas
int CloseHour = 19;
int CloseMinute = 0;
double PipsFromOpen = 250;
double MaxSpreadPips = 10;
double StopLossPaddingPips = 0;

int OnInit()
{
    if (!EAHelper::CheckSymbolAndTimeFrame(ForcedSymbol, ForcedTimeFrame))
    {
        return INIT_PARAMETERS_INCORRECT;
    }

    PRBuys = new PriceRange(MagicNumbers::NasMorningPriceRangeBuys, OP_BUY, MaxCurrentSetupTradesAtOnce, MaxTradesPerDay, StopLossPaddingPips, MaxSpreadPips, RiskPercent,
                            EntryWriter, ExitWriter, ErrorWriter);

    PRBuys.mCloseHour = CloseHour;
    PRBuys.mCloseMinute = CloseMinute;
    PRBuys.mPipsFromOpen = PipsFromOpen;

    PRBuys.SetPartialCSVRecordWriter(PartialWriter);
    PRBuys.AddTradingSession(16, 30, 16, 35);

    PRSells = new PriceRange(MagicNumbers::NasMorningPriceRangeSells, OP_SELL, MaxCurrentSetupTradesAtOnce, MaxTradesPerDay, StopLossPaddingPips, MaxSpreadPips, RiskPercent,
                             EntryWriter, ExitWriter, ErrorWriter);

    PRSells.mCloseHour = CloseHour;
    PRSells.mCloseMinute = CloseMinute;
    PRSells.mPipsFromOpen = PipsFromOpen;

    PRSells.SetPartialCSVRecordWriter(PartialWriter);
    PRSells.AddTradingSession(16, 30, 16, 35);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    delete PRBuys;
    delete PRSells;

    delete EntryWriter;
    delete PartialWriter;
    delete ExitWriter;
    delete ErrorWriter;
}

void OnTick()
{
    PRBuys.Run();
    PRSells.Run();
}