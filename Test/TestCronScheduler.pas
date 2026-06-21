unit TestCronScheduler;

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.DateUtils,
  CronScheduler; // наш модуль

type
  [TestFixture]
  TCronSchedulerTests = class
  private
    function MakeTime(Y, M, D, H, N: Word): TDateTime;
  public
    [Test] procedure Parse_Simple_Asterisk;
    [Test] procedure Parse_Slash_Every5;
    [Test] procedure Parse_Range;
    [Test] procedure NextTime_EveryMinute;
    [Test] procedure NextTime_Every5Minutes;
    [Test] procedure NextTime_SpecificHour;
    [Test] procedure NextTime_DayOfMonth_And_DayOfWeek;
    [Test] procedure NextTime_MonthTransition;
    [Test] procedure Parse_Comma_Separated;

    [Test] procedure Parse_OneTime_Task;
    [Test] procedure Parse_OneTime_Seconds;
    [Test] procedure Parse_OneTime_Minutes;
    [Test] procedure Parse_OneTime_Hours;
    [Test] procedure NextTime_OneTime_ReturnsZero;
  end;

implementation

function TCronSchedulerTests.MakeTime(Y, M, D, H, N: Word): TDateTime;
begin
  Result:= EncodeDateTime(Y, M, D, H, N, 0, 0);
end;
procedure TCronSchedulerTests.Parse_Simple_Asterisk;
begin
  const T = TCronTask.Create('test', '* * * * *');
  try
    Assert.IsTrue(T.MinutesWild, 'Minutes should be wildcard');
    Assert.IsTrue(T.HoursWild, 'Hours should be wildcard');
    Assert.IsTrue(T.DaysWild, 'Days should be wildcard');
    Assert.IsTrue(T.MonthsWild, 'Months should be wildcard');
    Assert.IsTrue(T.WeekDaysWild, 'Weekdays should be wildcard');
    Assert.AreEqual(60, Length(T.Minutes));
    Assert.AreEqual(24, Length(T.Hours));
    Assert.AreEqual(7, Length(T.WeekDays));
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.Parse_Slash_Every5;
begin
  const T = TCronTask.Create('test', '*/5 * * * *');
  try
    Assert.AreEqual(12, Length(T.Minutes));
    Assert.AreEqual(24, Length(T.Hours));
    Assert.IsTrue(IntArrayContains(T.Minutes, 0));
    Assert.IsTrue(IntArrayContains(T.Minutes, 5));
    Assert.IsTrue(IntArrayContains(T.Minutes, 55));
    Assert.IsFalse(IntArrayContains(T.Minutes, 1));
    Assert.IsFalse(IntArrayContains(T.Minutes, 4));
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.Parse_Comma_Separated;
begin
  const T = TCronTask.Create('test', '59 7,19 * * *'); // Каждый день в 7:59 и 19:59
  try
    Assert.AreEqual(1, Length(T.Minutes));
    Assert.AreEqual(2, Length(T.Hours));
    Assert.IsTrue(IntArrayContains(T.Minutes, 59));
    Assert.IsTrue(IntArrayContains(T.Hours, 7));
    Assert.IsTrue(IntArrayContains(T.Hours, 19));
    Assert.IsFalse(IntArrayContains(T.Minutes, 0));
    Assert.IsFalse(IntArrayContains(T.Hours, 0));
    Assert.IsFalse(IntArrayContains(T.Hours, 3));
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.Parse_Range;
begin
  const T = TCronTask.Create('test', '10-12 * * * *');
  try
    Assert.AreEqual(3, Length(T.Minutes));
    Assert.IsFalse(IntArrayContains(T.Minutes, 0));
    Assert.IsTrue(IntArrayContains(T.Minutes, 10));
    Assert.IsTrue(IntArrayContains(T.Minutes, 12));
    Assert.IsFalse(IntArrayContains(T.Minutes, 13));
    Assert.AreEqual(24, Length(T.Hours));
    Assert.AreEqual(7, Length(T.WeekDays));
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.NextTime_EveryMinute;
var
  FromTime, Next: TDateTime;
begin
  const T = TCronTask.Create('test', '* * * * *');
  try
    FromTime:= MakeTime(2025,1,1,10,0);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,1,1,10,1), Next, 'Next minute should be +1');
  finally
    T.Free;
  end;
end;
procedure TCronSchedulerTests.NextTime_Every5Minutes;
var
  FromTime, Next: TDateTime;
begin
  const T = TCronTask.Create('test', '*/5 * * * *');
  try
    FromTime:= MakeTime(2025,1,1,10,2);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,1,1,10,5), Next);
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.NextTime_SpecificHour;
var
  FromTime, Next: TDateTime;
begin
  const T = TCronTask.Create('test', '0 7 * * *'); // каждый день в 07:00
  try
    FromTime:= MakeTime(2025,1,1,6,50);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,1,1,7,0), Next);

    FromTime:= MakeTime(2025,1,1,7,1);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,1,2,7,0), Next);
  finally
    T.Destroy;
  end;
end;
procedure TCronSchedulerTests.NextTime_DayOfMonth_And_DayOfWeek;
var
  T: TCronTask;
  FromTime, Next: TDateTime;
begin
  // сработает если число месяца=15 или день недели=понедельник
  T:= TCronTask.Create('test-1', '0 12 15 * 1');
  try
    FromTime:= MakeTime(2025,10,09,10,0);   // Тут уже в понедельник 13го наступит
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,10,13,12,0), Next);
  finally
    T.Free;
  end;

  T:= TCronTask.Create('test-2', '7 12 15 * 4');
  try
    FromTime:= MakeTime(2025,10,11,10,0);  // А тут в среду 15го
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,10,15,12,7), Next);
  finally
    T.Free;
  end;
end;
procedure TCronSchedulerTests.NextTime_MonthTransition;
var
  FromTime, Next: TDateTime;
begin
  const T = TCronTask.Create('test', '0 0 1 * *'); // Кажде 1-е число
  try
    FromTime:= MakeTime(2025,10,31,10,0);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,11,1,0,0), Next);

    FromTime:= MakeTime(2025,10,7,12,0);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2025,11,1,0,0), Next);

    FromTime:= MakeTime(2025,12,7,3,0);
    Next:= T.GetNextTime(FromTime);
    Assert.AreEqual(MakeTime(2026,1,1,0,0), Next);
  finally
    T.Destroy;
  end;
end;

{$REGION 'Тесты разовых задач (One-time tasks)'}
procedure TCronSchedulerTests.Parse_OneTime_Task;
begin
  const T1 = TCronTask.Create('test1', '+5m');
  const T2 = TCronTask.Create('test2', '* * * * *');
  try
    Assert.IsTrue(T1.IsOneTime, 'Task with + should be marked as one-time');
    Assert.IsFalse(T2.IsOneTime, 'Standard cron task should not be one-time');
  finally
    T1.Free;
    T2.Free;
  end;
end;
procedure TCronSchedulerTests.Parse_OneTime_Seconds;
var
  Expected: TDateTime;
begin
  Expected:= IncSecond(Now, 45); // +45s
  const T = TCronTask.Create('test', '+45s');
  try
    // Допускаем погрешность в 1 секунду из-за времени выполнения самого теста
    Assert.IsTrue(SecondsBetween(Expected, T.NextTime) <= 1, 'NextTime should be ~45 seconds from Now');
  finally
    T.Free;
  end;
end;
procedure TCronSchedulerTests.Parse_OneTime_Minutes;
var
  Expected: TDateTime;
begin
  Expected:= IncMinute(Now, 15); // +15m
  const T = TCronTask.Create('test', '+15m');
  try
    Assert.IsTrue(SecondsBetween(Expected, T.NextTime) <= 1, 'NextTime should be ~15 minutes from Now');
  finally
    T.Free;
  end;
end;
procedure TCronSchedulerTests.Parse_OneTime_Hours;
var
  Expected: TDateTime;
begin
  Expected:= IncHour(Now, 2); // +2h
  const T = TCronTask.Create('test', '+2h');
  try
    Assert.IsTrue(SecondsBetween(Expected, T.NextTime) <= 1, 'NextTime should be ~2 hours from Now');
  finally
    T.Free;
  end;
end;
procedure TCronSchedulerTests.NextTime_OneTime_ReturnsZero;
begin
  const T = TCronTask.Create('test', '+1m');
  try
    Assert.AreEqual(TDateTime(0), T.GetNextTime(Now), 'GetNextTime must return 0 for completed one-time tasks');
  finally
    T.Free;
  end;
end;
{$ENDREGION}


initialization
  TDUnitX.RegisterTestFixture(TCronSchedulerTests);

end.

