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
    procedure FormDestroy(Sender: TObject);
  private
    FCron: TCronThread;
  public
    { Public declarations }
  end;

var
  Form5: TForm5;

implementation

{$R *.dfm}

procedure TForm5.FormCreate(Sender: TObject);
begin
  FCron:= TCronThread.Create();
  FCron.OnExecute:=
    procedure(Sender: TObject; const TaskName: string)
    begin
      mmoLog.Lines.Add('['+TimeToStr(Now)+'] Выполнено: ' + TaskName);
    end;

  // формат: минута час день_месяца месяц день_недели
  // * * * * * = каждую минуту
  // */5 * * * * = каждые 5 минут
  FCron.AddTask('Каждую минуту', '* * * * *');
  FCron.AddTask('Каждые 3 минуты', '*/3 * * * *');
  FCron.AddTask('Каждые 5 минут', '*/5 * * * *');
  FCron.AddTask('Каждый день в 22:00', '0 22 * * *');
//  FCron.AddTask('Каждый день утром и вечером', '59 7,19 * * *');
//  FCron.AddTask('Каждый день в 7:59', '59 7 * * *');
end;

procedure TForm5.FormDestroy(Sender: TObject);
begin
  if Assigned(FCron) then FreeAndNil(FCron);
end;

end.
