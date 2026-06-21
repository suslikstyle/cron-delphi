unit CronScheduler;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  System.Types;

type
  // Обработчик события (анонимные процедуры поддерживаются)
  TCronEvent = reference to procedure(Sender: TObject; const TaskName: string);

  TCronTask = class
  private
    FName: string;
    FCronExpr: string;
    FMinutes, FHours, FDays, FMonths, FWeekDays: TArray<Integer>;
    FMinutesWild, FHoursWild, FDaysWild, FMonthsWild, FWeekDaysWild: Boolean;
    FNextTime: TDateTime;
    procedure ParseExpression;
    procedure ParseField(const Field: string; MinVal, MaxVal: Integer;
      out Values: TArray<Integer>; out IsWildcard: Boolean; IsDayOfWeek: Boolean = False);
  public
    constructor Create(const AName, ACronExpr: string);
    function GetNextTime(const FromTime: TDateTime): TDateTime;

    // Публичные свойства (read-only) — они нужны для тестов
    property Name: string read FName;
    property CronExpr: string read FCronExpr;
    property NextTime: TDateTime read FNextTime write FNextTime;

    property Minutes: TArray<Integer> read FMinutes;
    property Hours: TArray<Integer> read FHours;
    property Days: TArray<Integer> read FDays;
    property Months: TArray<Integer> read FMonths;
    property WeekDays: TArray<Integer> read FWeekDays;

    property MinutesWild: Boolean read FMinutesWild;
    property HoursWild: Boolean read FHoursWild;
    property DaysWild: Boolean read FDaysWild;
    property MonthsWild: Boolean read FMonthsWild;
    property WeekDaysWild: Boolean read FWeekDaysWild;
  end;

  // Использовать для привязки какого-либо события ко времени
  TCronThread = class(TThread)
  private
    FTasks: TObjectList<TCronTask>;
    FOnExecute: TCronEvent;
    FEvent: TEvent;
    FLock: TCriticalSection;
    FToleranceSeconds: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddTask(const AName, ACronExpr: string);
    procedure ClearTasks;
    procedure Stop;

    property OnExecute: TCronEvent read FOnExecute write FOnExecute;
    // допустимое окно (сек), если планировщик проснулся с задержкой
    property ToleranceSeconds: Integer read FToleranceSeconds write FToleranceSeconds;
  end;

  function IntArrayContains(const Arr: TArray<Integer>; v: Integer): Boolean;

implementation

uses
  System.StrUtils;

{$REGION 'Вспомогательные функции'}
procedure AddUniqueInt(var Arr: TArray<Integer>; v: Integer);
var
  i: Integer;
begin
  for i := 0 to Length(Arr)-1 do
    if Arr[i] = v then Exit;
  SetLength(Arr, Length(Arr)+1);
  Arr[High(Arr)] := v;
end;
function IntArrayContains(const Arr: TArray<Integer>; v: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to Length(Arr)-1 do
    if Arr[i] = v then Exit(True);
  Result := False;
end;
procedure SortUnique(var Arr: TArray<Integer>);
var
  L: TList<Integer>;
  i: Integer;
begin
  L := TList<Integer>.Create;
  try
    for i := 0 to Length(Arr)-1 do
      if L.IndexOf(Arr[i]) = -1 then
        L.Add(Arr[i]);
    L.Sort;
    SetLength(Arr, L.Count);
    for i := 0 to L.Count-1 do
      Arr[i] := L[i];
  finally
    L.Free;
  end;
end;
{$ENDREGION}

{$REGION 'TCronTask'}
constructor TCronTask.Create(const AName, ACronExpr: string);
begin
  inherited Create;
  FName:= AName;
  FCronExpr:= Trim(ACronExpr);
  ParseExpression;
  // начальное NextTime (строго > Now)
  FNextTime:= GetNextTime(Now);
end;
procedure TCronTask.ParseField(const Field: string; MinVal, MaxVal: Integer; out Values: TArray<Integer>; out IsWildcard: Boolean; IsDayOfWeek: Boolean);
var
  Parts: TArray<string>;
  i, startVal, endVal, stepVal, v: Integer;
  tok: string;
  L: TList<Integer>;
begin
  L:= TList<Integer>.Create;
  try
    Values:= [];
    IsWildcard:= False;
    tok:= Trim(Field);
    if tok = '' then
      raise Exception.Create('Empty cron field');

    if tok = '*' then begin
      IsWildcard := True;
      for i:= MinVal to MaxVal do
        L.Add(i);
    end else begin
      Parts:= tok.Split([',']);
      for i:= 0 to High(Parts) do begin
        tok:= Trim(Parts[i]);
        if tok = '' then Continue;

        // step form: */N
        if (Length(tok) > 2) and (Copy(tok,1,2) = '*/') then begin
          stepVal:= StrToIntDef(Copy(tok,3,MaxInt), 1);
          if stepVal <= 0 then stepVal := 1;
          var j: Integer;
          for j:= MinVal to MaxVal do
            if ((j - MinVal) mod stepVal) = 0 then
              if L.IndexOf(j) = -1 then L.Add(j);
          Continue;
        end;

        // range: A-B
        if Pos('-', tok) > 0 then begin
          startVal:= StrToIntDef(Trim(Copy(tok,1,Pos('-',tok)-1)), MinVal);
          endVal:= StrToIntDef(Trim(Copy(tok,Pos('-',tok)+1,MaxInt)), MaxVal);
          if startVal < MinVal then startVal:= MinVal;
          if endVal > MaxVal then endVal:= MaxVal;
          var k: Integer;
          for k:= startVal to endVal do
            if L.IndexOf(k) = -1 then L.Add(k);
          Continue;
        end;

        // single number
        v:= StrToIntDef(tok, MinVal - 1);
        if IsDayOfWeek and (v = 7) then v:= 0; // 7 as Sunday -> 0
        if (v >= MinVal) and (v <= MaxVal) then
          if L.IndexOf(v) = -1 then L.Add(v);
      end;
    end;

    // copy to array and sort/unique
    SetLength(Values, L.Count);
    for i:= 0 to L.Count - 1 do
      Values[i]:= L[i];
    SortUnique(Values);
  finally
    L.Free;
  end;
end;
procedure TCronTask.ParseExpression;
var
  Fields: TArray<string>;
begin
  Fields:= FCronExpr.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Fields) < 5 then
    raise Exception.Create('Cron expression must have 5 fields: minute hour dom month dow');

  ParseField(Fields[0], 0, 59, FMinutes, FMinutesWild, False);
  ParseField(Fields[1], 0, 23, FHours, FHoursWild, False);
  ParseField(Fields[2], 1, 31, FDays, FDaysWild, False);
  ParseField(Fields[3], 1, 12, FMonths, FMonthsWild, False);
  ParseField(Fields[4], 0, 6, FWeekDays, FWeekDaysWild, True);  // dow: 0..6, allow 7 as Sunday
end;
function TCronTask.GetNextTime(const FromTime: TDateTime): TDateTime;
var
  TryDt, LimitDt: TDateTime;
  Y, Mo, D, H, Mi, S, MSec: Word;
  dow: Integer;
  minuteMatch, hourMatch, monthMatch, dayMatch: Boolean;
  domSpecified, dowSpecified: Boolean;
begin
  // Найти следующую дату/время с секундами = 0 и строго > FromTime
  DecodeDateTime(FromTime, Y, Mo, D, H, Mi, S, MSec);

  TryDt:= EncodeDateTime(Y, Mo, D, H, Mi, 0, 0);
  if TryDt <= FromTime then
    TryDt:= IncMinute(TryDt, 1);

  // ограничение поиска
  LimitDt:= IncYear(FromTime, 5);

  domSpecified:= not FDaysWild;
  dowSpecified:= not FWeekDaysWild;

  while TryDt <= LimitDt do begin
    DecodeDateTime(TryDt, Y, Mo, D, H, Mi, S, MSec);

    // Быстрый перескок месяцев
    monthMatch:= FMonthsWild or IntArrayContains(FMonths, Mo);
    if not monthMatch then begin
      TryDt:= StartOfTheMonth(IncMonth(TryDt, 1));
      Continue;
    end;

    // Быстрый перескок дней
    dow:= DayOfWeek(TryDt) - 1;
    if (not domSpecified) and (not dowSpecified) then
      dayMatch:= True
    else if domSpecified and dowSpecified then
      dayMatch:= IntArrayContains(FDays, D) or IntArrayContains(FWeekDays, dow)
    else if domSpecified then
      dayMatch:= IntArrayContains(FDays, D)
    else dayMatch:= IntArrayContains(FWeekDays, dow);

    if not dayMatch then begin
      TryDt:= StartOfTheDay(IncDay(TryDt, 1));
      Continue;
    end;

    // Быстрый перескок часов
    hourMatch:= FHoursWild or IntArrayContains(FHours, H);
    if not hourMatch then begin
      TryDt:= RecodeMinute(TryDt, 0); // Обнуляем минуты
      TryDt:= IncHour(TryDt, 1);
      Continue;
    end;

    // Если все совпало
    minuteMatch:= FMinutesWild or IntArrayContains(FMinutes, Mi);
    if minuteMatch then Exit(TryDt);

    TryDt:= IncMinute(TryDt, 1);
  end;

  raise Exception.Create('Cannot find next cron time within search window for: ' + FCronExpr);
end;
{$ENDREGION}

{$REGION 'TCronThread'}
constructor TCronThread.Create;
begin
  inherited Create(False);
  FreeOnTerminate:= False;
  FTasks:= TObjectList<TCronTask>.Create(True);
  FEvent:= TEvent.Create(nil, False, False, '');
  FLock:= TCriticalSection.Create;
  FToleranceSeconds:= 60;
//  Start;
end;
destructor TCronThread.Destroy;
begin
  Stop;
  FEvent.Free;
  FLock.Free;
  FTasks.Free;
  inherited;
end;
procedure TCronThread.AddTask(const AName, ACronExpr: string);
begin
  const T = TCronTask.Create(AName, ACronExpr);
  FLock.Enter;
  try
    FTasks.Add(T);
    // задача уже имеет рассчитанное NextTime в конструкторе
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;
procedure TCronThread.ClearTasks;
begin
  FLock.Enter;
  try
    FTasks.Clear;
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;
procedure TCronThread.Stop;
begin
  Terminate;
  FEvent.SetEvent;
  // не ждём, если вызываем Stop из самого потока
  if TThread.CurrentThread.ThreadID <> ThreadID then
    WaitFor;
end;
procedure TCronThread.Execute;
const
  MAX_WAIT_MS = 60 * 60 * 1000;
var
  Soonest, NowTime: TDateTime;
  WaitMs: Cardinal;
  TriggerTasks: TList<TCronTask>;
  Task: TCronTask;
begin
  Sleep(500);
  TriggerTasks := TList<TCronTask>.Create;
  try
    while not Terminated do begin
      // Поиск ближайшей задачи
      FLock.Enter;
      try
        Soonest:= 0;
        for Task in FTasks do
          if (Soonest = 0) or (Task.NextTime < Soonest) then
            Soonest:= Task.NextTime;
      finally
        FLock.Leave;
      end;

      // Если задач нет спим до добавления
      if Soonest = 0 then begin
        FEvent.WaitFor(INFINITE);
        Continue;
      end;

      NowTime:= Now;

      // Если время еще не пришло - ждем
      if Soonest > NowTime then begin
        WaitMs:= Round((Soonest-NowTime) * MSecsPerDay);
        if WaitMs = 0 then WaitMs:= 1;
        if WaitMs > MAX_WAIT_MS then WaitMs:= MAX_WAIT_MS;
        FEvent.WaitFor(WaitMs);
        Continue;
      end;

      // Время пришло. Собираем задачи, которые нужно выполнить
      TriggerTasks.Clear;
      FLock.Enter;
      try
        NowTime:= Now;
        for Task in FTasks do begin
          // Если время задачи в прошлом или сейчас
          if Task.NextTime <= NowTime then begin

            // Если мы проспали не дольше, чем разрешено толерантностью
            if SecondsBetween(NowTime, Task.NextTime) <= FToleranceSeconds then
              TriggerTasks.Add(Task);

            // Вычисляем следующее время от текущего момента, чтобы предотвратить бесконечный цикл застревания в прошлом
            Task.NextTime:= Task.GetNextTime(NowTime);
          end;
        end;
      finally
        FLock.Leave;
      end;

      // Вызов событий вне блокировки (чтобы не тормозить AddTask)
      for Task in TriggerTasks do begin
        if Assigned(FOnExecute) then begin
          var TaskName:= Task.Name; // Локальный захват переменной для анонимного потока

          TThread.Queue(nil,
            procedure
            begin
              try
                FOnExecute(Self, TaskName);
              except
              end;
            end);
        end;
      end;

    end;
  finally
    TriggerTasks.Free;
  end;
end;
{$ENDREGION}

end.

