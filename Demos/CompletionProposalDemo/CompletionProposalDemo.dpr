program CompletionProposalDemo;

uses
  Forms,
  FormMain_ctCode in 'FormMain_ctCode.pas' {Form1},
  Vcl.Themes,
  Vcl.Styles;

{$R *.RES}

begin
  Application.Initialize;
  TStyleManager.TrySetStyle('Windows11 Modern Dark');
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
