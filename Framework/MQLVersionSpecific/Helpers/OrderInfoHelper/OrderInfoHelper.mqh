//+------------------------------------------------------------------+
//|                                                     OrderInfoHelper.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#ifdef __MQL4__
#include <Wantanites\Framework\MQLVersionSpecific\Helpers\OrderInfoHelper\MQL4OrderInfoHelper.mqh>
#endif
#ifdef __MQL5__
#include <Wantanites\Framework\MQLVersionSpecific\Helpers\OrderInfoHelper\MQL5OrderInfoHelper.mqh>
#endif

class OrderInfoHelper
{
public:
    static int CountOtherEAOrders(bool todayOnly, int &magicNumbers[], int &orderCount);
    static int FindActiveTicketsByMagicNumber(bool todayOnly, int magicNumber, int &tickets[]);
    static int FindNewTicketAfterPartial(int magicNumber, double openPrice, datetime orderOpenTime, int &ticket);
};

int OrderInfoHelper::CountOtherEAOrders(bool todayOnly, int &magicNumbers[], int &orderCount)
{
    return VersionSpecificOrderInfoHelper::CountOtherEAOrders(todayOnly, magicNumbers, tickets);
}

int OrderInfoHelper::FindActiveTicketsByMagicNumber(bool todayOnly, int magicNumber, int &tickets[])
{
    return VersionSpecificOrderInfoHelper::FindActiveTicketsByMagicNumber(todayOnly, magicNumber, tickets);
}

int OrderInfoHelper::FindNewTicketAfterPartial(int magicNumber, double openPrice, datetime orderOpenTime, int &ticket)
{
    return VersionSpecificOrderInfoHelper::FindNewTicketAfterPartial(magicNumber, openPrice, orderOpenTime, ticket);
}