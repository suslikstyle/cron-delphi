unit Test;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  CronScheduler, Vcl.StdCtrls;

type
  TForm5 = class(TForm)
    mmoLog: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    Cron: TCronThread;
  public
    { Public declarations }
  end;

var
  Form5: TForm5;

implementation

{$R *.dfm}

procedure TForm5.FormCreate(Sender: TObject);
begin
  Cron:= TCronThread.Create;
  Cron.OnExecute:=
    procedure(Sender: TObject; const TaskName: string)
    begin
      mmoLog.Lines.Add('['+TimeToStr(Now)+'] Выполнено: ' + TaskName);
    end;

  // формат: минута час день_месяца месяц день_недели
  // * * * * * = каждую минуту
  // */5 * * * * = каждые 5 минут
//  Cron.AddTask('Каждую минуту', '* * * * *');
  Cron.AddTask('Каждый день утром и вечером', '59 7,19 * * *');
//  Cron.AddTask('Каждый день в 7:59', '59 7 * * *');
end;

end.
