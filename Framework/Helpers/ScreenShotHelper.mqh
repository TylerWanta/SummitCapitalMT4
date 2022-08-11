//+------------------------------------------------------------------+
//|                                             ScreenShotHelper.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <SummitCapital\Framework\Helpers\OrderHelper.mqh>
#include <SummitCapital\Framework\Constants\Index.mqh>

class ScreenShotHelper
{
private:
    static string DateTimeToFilePathString(datetime dt);

public:
    static string TryTakeScreenShot(string directory, string suffix);
    static string TryTakeBeforeScreenShot(string directory, string suffix);
    static string TryTakeAfterScreenShot(string directory, string suffix);
};

static string ScreenShotHelper::DateTimeToFilePathString(datetime dt)
{
    return IntegerToString(TimeYear(dt)) + "-" +
           IntegerToString(TimeMonth(dt)) + "-" +
           IntegerToString(TimeDay(dt)) + "_" +
           IntegerToString(TimeHour(dt)) + "-" +
           IntegerToString(TimeMinute(dt)) + "-" +
           IntegerToString(TimeSeconds(dt));
}

static string ScreenShotHelper::TryTakeScreenShot(string directory, string suffix = "")
{
    string imageName = DateTimeToFilePathString(TimeCurrent()) + suffix + ".png";
    string filePath = directory + "Images/" + imageName;

    if (!ChartScreenShot(ChartID(), filePath, 2000, 800, ALIGN_RIGHT))
    {
        int error = GetLastError();
        imageName = "Error: " + IntegerToString(error);
    }

    return imageName;
}

static string ScreenShotHelper::TryTakeBeforeScreenShot(string directory, string suffix = "")
{
    string imageName = DateTimeToFilePathString(TimeCurrent()) + "_Before" + suffix + ".png";
    string filePath = directory + "Images/" + imageName;

    if (!ChartScreenShot(ChartID(), filePath, 2000, 800, ALIGN_RIGHT))
    {
        int error = GetLastError();
        imageName = "Error: " + IntegerToString(error);
    }

    return imageName;
}

static string ScreenShotHelper::TryTakeAfterScreenShot(string directory, string suffix = "")
{
    string imageName = DateTimeToFilePathString(TimeCurrent()) + "_After" + suffix + ".png";
    string filePath = directory + "Images/" + imageName;

    if (!ChartScreenShot(ChartID(), filePath, 2000, 800, ALIGN_RIGHT))
    {
        int error = GetLastError();
        imageName = "Error: " + IntegerToString(error);
    }

    return imageName;
}
