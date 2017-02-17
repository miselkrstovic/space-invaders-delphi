unit Settings;

interface

type
  TSettings = class
  public
    AlienScoreAlpha : Integer;
    AlienScoreBeta : Integer;
    AlienScoreGamma  : Integer;
    AlienScoreMysteryShip : Integer;

    HorizontalPixelShift : Integer;
    VerticalPixelShift : Integer;
    AlienMissilePixelShift : Integer;
    PlayerMissilePixelShift : Integer;

    MaxAlienMissileCount : Integer;
    MaxPlayerMissileCount : Integer;

    XAxisAcceleration : Double;
    YAxisAcceleration : Double;

    AlienMeshWidth : Integer;
    AlienMeshHeight : Integer;

    WindowHeight : Integer;
    WindowWidth : Integer;

    InitialPlayerLives : Integer;
    FPS : Integer;
    MysteryShipFrequency : Integer;

    ScoreMarkForNewLife : Integer;

    constructor Create;
  end;

var
  GameSettings : TSettings;

implementation

{ TSettings }

constructor TSettings.Create;
begin
  //  Alpha aliens is 10 points
  AlienScoreAlpha  := 10;
  //  Beta aliens is 20 points
  AlienScoreBeta := 20;
  //  Gamma aliens is 30 points
  AlienScoreGamma  := 30;
  //  Mystery ship is 50 points
  AlienScoreMysteryShip := 300;

  HorizontalPixelShift := 2;
  VerticalPixelShift := 16; //  Alien descent at each horizontal hit is 8 pixels

  AlienMissilePixelShift := 7;
  PlayerMissilePixelShift := 14; //  Alien descent at each horizontal hit is 8 pixels

  MaxPlayerMissileCount := 1; // Default is 1
  MaxAlienMissileCount := 2; // Default is 2

  XAxisAcceleration := 0.7; // Aliens movement speeds up
  YAxisAcceleration := 0; // Aliens movement speeds up

  AlienMeshWidth := 11;
  AlienMeshHeight := 5;

  WindowHeight := 256;
  WindowWidth := 256;

  InitialPlayerLives := 3;
  FPS := 30;
  MysteryShipFrequency := 30; // Seconds

  ScoreMarkForNewLife := 1500;
end;

initialization
  GameSettings := TSettings.Create;
finalization
  GameSettings.Free;
end.
