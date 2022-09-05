//+------------------------------------------------------------------+
//|                                      EmptyPartialTradeRecord.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

class EmptyPartialTradeRecord
{
private:
public:
    EmptyPartialTradeRecord();
    ~EmptyPartialTradeRecord();

    void WriteHeaders(int fileHandle, bool writeDelimiter);
    void WriteRecord(int fileHandle, bool writeDelimiter);
};

EmptyPartialTradeRecord::EmptyPartialTradeRecord() {}
EmptyPartialTradeRecord::~EmptyPartialTradeRecord() {}

void EmptyPartialTradeRecord::WriteHeaders(int fileHandle, bool writeDelimiter = false) {}
void EmptyPartialTradeRecord::WriteRecord(int fileHandle, bool writeDelimiter = false) {}