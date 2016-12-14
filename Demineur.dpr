program Demineur;

uses
  System.StartUpCopy,
  FMX.Forms,
  uFormDemineur in 'uFormDemineur.pas' {FormDemineur},
  ClassDemineur in 'ClassDemineur.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormDemineur, FormDemineur);
  Application.Run;
end.
