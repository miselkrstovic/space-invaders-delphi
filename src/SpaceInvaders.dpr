program SpaceInvaders;



uses
  Forms,
  Main in 'Main.pas' {frmMain},
  ScoreKeeper in 'ScoreKeeper.pas',
  Settings in 'Settings.pas',
  Missiles in 'Missiles.pas',
  Aliens in 'Aliens.pas',
  Engine in 'Engine.pas',
  Explosions in 'Explosions.pas',
  Bunkers in 'Bunkers.pas',
  Utilities in 'Utilities.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.Title := 'Space Invaders';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
