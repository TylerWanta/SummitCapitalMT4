//+------------------------------------------------------------------+
//|                                              ExecutionErrors.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

class ExecutionErrors
{
public:
    // 6000s Are For Indicator Errors
    static int ExecutionErrors::SUBSEQUENT_MB_DOES_NOT_EXIST;
    static int ExecutionErrors::MB_IS_NOT_MOST_RECENT;
    static int ExecutionErrors::EQUAL_MB_TYPES;
    static int ExecutionErrors::NOT_EQUAL_MB_TYPES;
    static int ExecutionErrors::BULLISH_RETRACEMENT_IS_NOT_VALID;
    static int ExecutionErrors::BEARISH_RETRACEMENT_IS_NOT_VALID;

    // 6100s Are For Order Errors
    static int ExecutionErrors::NEW_STOPLOSS_EQUALS_OLD;
    static int ExecutionErrors::STOP_ORDER_ENTRY_FURTHER_THEN_PRICE;

    // 6200s Are for MQL Extension Errors
    static int ExecutionErrors::COULD_NOT_RETRIEVE_LOW;
    static int ExecutionErrors::COULD_NOT_RETRIEVE_HIGH;
};

// 6000s Are For Indicator Errors
static int ExecutionErrors::SUBSEQUENT_MB_DOES_NOT_EXIST = 6001;
static int ExecutionErrors::MB_IS_NOT_MOST_RECENT = 6002;
static int ExecutionErrors::EQUAL_MB_TYPES = 6003;
static int ExecutionErrors::NOT_EQUAL_MB_TYPES = 6004;
static int ExecutionErrors::BULLISH_RETRACEMENT_IS_NOT_VALID = 6005;
static int ExecutionErrors::BEARISH_RETRACEMENT_IS_NOT_VALID = 6006;

// 6100s Are For Order Errors
static int ExecutionErrors::NEW_STOPLOSS_EQUALS_OLD = 6100;
static int ExecutionErrors::STOP_ORDER_ENTRY_FURTHER_THEN_PRICE = 6101;

// 6200s Are for MQL Extension Errors
static int ExecutionErrors::COULD_NOT_RETRIEVE_LOW = 6200;
static int ExecutionErrors::COULD_NOT_RETRIEVE_HIGH = 6201;