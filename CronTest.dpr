program CronTest;

uses
  Vcl.Forms,
  Test in 'Test.pas' {Form5},
  CronScheduler in 'CronScheduler.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Carbon');
  Application.CreateForm(TForm5, Form5);
  Application.Run;
end.
