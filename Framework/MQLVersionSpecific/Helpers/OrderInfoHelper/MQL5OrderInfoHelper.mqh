//+------------------------------------------------------------------+
//|                                                     VersionSpecificOrderInfoHelper.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <Wantanites\Framework\Helpers\MailHelper.mqh>

class VersionSpecificOrderInfoHelper
{
public:
    static int TotalCurrentOrders();

    static int CountOtherEAOrders(bool todayOnly, List<int> &magicNumbers, int &orderCount);
    static int GetAllActiveTickets(List<int> &ticketNumbers);
    static int FindActiveTicketsByMagicNumber(int magicNumber, int &tickets[]);
    static int FindNewTicketAfterPartial(int magicNumber, double openPrice, datetime orderOpenTime, int &ticket);
    static double GetTotalLotsForSymbolAndDirection(string symbol, TicketType type);
};

static int VersionSpecificOrderInfoHelper::TotalCurrentOrders()
{
    return OrdersTotal() + PositionsTotal();
}

static int VersionSpecificOrderInfoHelper::CountOtherEAOrders(bool todayOnly, List<int> &magicNumbers, int &orderCount)
{
    // pending orders
    for (int i = 0; i < OrdersTotal(); i++)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        if (!OrderSelect(ticket))
        {
            int error = GetLastError();
            MailHelper::Send("Failed To Select Open Order By Position When Countint Other EA Orders",
                             "Total Orders: " + IntegerToString(OrdersTotal()) + "\n" +
                                 "Current Order Index: " + IntegerToString(i) + "\n" +
                                 IntegerToString(error));
            return error;
        }

        int magicNumber = OrderGetInteger(ORDER_MAGIC);
        for (int j = 0; j < magicNumbers.Size(); j++)
        {
            if (magicNumber == magicNumbers[j])
            {
                MqlDateTime currentTime = DateTimeHelper::CurrentTime();
                MqlDateTime openTime = DateTimeHelper::ToMQLDateTime(OrderGetInteger(ORDER_TIME_SETUP));

                if (todayOnly && (openTime.year != currentTime.year || openTime.mon != currentTime.mon || openTime.day != currentTime.day))
                {
                    continue;
                }

                orderCount += 1;
            }
        }
    }

    // active orders
    for (int i = 0; i < PositionsTotal(); i++)
    {
        string symbol = PositionGetSymbol(i);
        if (!PositionSelect(symbol))
        {
            int error = GetLastError();
            MailHelper::Send("Failed To Select Open Position By Symbol When Counting Other EA Orders",
                             "Total Positions: " + IntegerToString(PositionsTotal()) + "\n" +
                                 "Current Position Index: " + IntegerToString(i) + "\n" +
                                 IntegerToString(error));
            return error;
        }

        int magicNumber = PositionGetInteger(POSITION_MAGIC);
        for (int j = 0; j < magicNumbers.Size(); j++)
        {
            if (magicNumber == magicNumbers[j])
            {
                MqlDateTime currentTime = DateTimeHelper::CurrentTime();
                MqlDateTime openTime = DateTimeHelper::ToMQLDateTime(PositionGetInteger(POSITION_TIME));

                if (todayOnly && (openTime.year != currentTime.year || openTime.mon != currentTime.mon || openTime.day != currentTime.day))
                {
                    continue;
                }

                orderCount += 1;
            }
        }
    }

    return Errors::NO_ERROR;
}

static int VersionSpecificOrderInfoHelper::GetAllActiveTickets(List<int> &ticketNumbers)
{
    // pending orders
    for (int i = 0; i < OrdersTotal(); i++)
    {
        int ticket = OrderGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        ticketNumbers.Add(ticket);
    }

    // active orders
    for (int i = 0; i < PositionsTotal(); i++)
    {
        int ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        ticketNumbers.Add(ticket);
    }

    return Errors::NO_ERROR;
}

static int VersionSpecificOrderInfoHelper::FindActiveTicketsByMagicNumber(int magicNumber, int &tickets[])
{
    // pending orders
    for (int i = 0; i < OrdersTotal(); i++)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        if (!OrderSelect(ticket))
        {
            int error = GetLastError();
            MailHelper::Send("Failed To Select Open Order By Position When Countint Other EA Orders",
                             "Total Orders: " + IntegerToString(OrdersTotal()) + "\n" +
                                 "Current Order Index: " + IntegerToString(i) + "\n" +
                                 IntegerToString(error));
            return error;
        }

        if (OrderGetInteger(ORDER_MAGIC) == magicNumber)
        {
            ArrayResize(tickets, ArraySize(tickets) + 1);
            tickets[ArraySize(tickets) - 1] = ticket;
        }
    }

    // active orders
    for (int i = 0; i < PositionsTotal(); i++)
    {
        string symbol = PositionGetSymbol(i);
        if (!PositionSelect(symbol))
        {
            int error = GetLastError();
            MailHelper::Send("Failed To Select Open Position By Symbol When Counting Other EA Orders",
                             "Total Positions: " + IntegerToString(PositionsTotal()) + "\n" +
                                 "Current Position Index: " + IntegerToString(i) + "\n" +
                                 IntegerToString(error));
            return error;
        }

        if (PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
            ArrayResize(tickets, ArraySize(tickets) + 1);
            tickets[ArraySize(tickets) - 1] = PositionGetInteger(POSITION_TICKET);
        }
    }

    return Errors::NO_ERROR;
}

static int VersionSpecificOrderInfoHelper::FindNewTicketAfterPartial(int magicNumber, double openPrice, datetime orderOpenTime, int &ticket)
{
    int error = Errors::NO_ERROR;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        string symbol = PositionGetSymbol(i);
        if (!PositionSelect(symbol))
        {
            error = GetLastError();
            MailHelper::Send("Failed To Select Open Position By Symbol When Counting Other EA Orders",
                             "Total Positions: " + IntegerToString(PositionsTotal()) + "\n" +
                                 "Current Position Index: " + IntegerToString(i) + "\n" +
                                 IntegerToString(error));
            continue;
        }

        if (PositionGetInteger(POSITION_MAGIC) != magicNumber)
        {
            continue;
        }

        if (NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits()) != NormalizeDouble(openPrice, Digits()))
        {
            continue;
        }

        if (PositionGetInteger(POSITION_TIME) != orderOpenTime)
        {
            continue;
        }

        ticket = PositionGetInteger(POSITION_TICKET);
        break;
    }

    return error;
}

double VersionSpecificOrderInfoHelper::GetTotalLotsForSymbolAndDirection(string symbol, TicketType type)
{
    double totalLots = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        if (OrderGetString(ORDER_SYMBOL) != symbol)
        {
            continue;
        }

        int orderType = OrderGetInteger(ORDER_TYPE);
        switch (type)
        {
        case TicketType::Buy:
        case TicketType::BuyStop:
        case TicketType::BuyLimit:
            if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
            {
                totalLots += OrderGetDouble(ORDER_VOLUME_CURRENT);
            }

            break;
        case TicketType::Sell:
        case TicketType::SellStop:
        case TicketType::SellLimit:
            if (orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)
            {
                totalLots += OrderGetDouble(ORDER_VOLUME_CURRENT);
            }

            break;
        default:
            break;
        }
    }

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            continue;
        }

        if (PositionGetString(POSITION_SYMBOL) != symbol)
        {
            continue;
        }

        int positionType = PositionGetInteger(POSITION_TYPE);
        if ((type == TicketType::Buy && positionType == POSITION_TYPE_BUY) || (type == TicketType::Sell && positionType == POSITION_TYPE_SELL))
        {
            totalLots += PositionGetDouble(POSITION_VOLUME);
        }
    }

    return totalLots;
}