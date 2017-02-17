unit Engine;

interface

{.$DEFINE ShowBGImage}

uses
  Classes, ExtCtrls, Types, Math, Controls, MMSystem, SysUtils, JclFileUtils,
  Aliens, Missiles, ScoreKeeper, Settings, Contnrs, JvThreadTimer, Windows,
  Graphics, Explosions, Bunkers, GR32_Image, GR32, GR32_Filters;

const
  ALIEN_CLEARANCE = 3;

type
  TArrayofBoolean = Array of Boolean;

  TGameState = (gsStopped, gsRunning, gsPaused, gsGameOver); // Pay attention that the initial state, it is the natural one

  TMysteryShipDirection = (msdLeft, msdRight);

  TMysteryShip = class
  private
    _Direction : TMysteryShipDirection;
    _MysteryShipCount : Integer;
    _MysteryShipEnabled : Boolean;
    _MysteryShipThreshold : Integer;
    function GetHeight: Integer;
    function GetWidth: Integer;
  protected
    procedure Paint;
  public
    Left : Integer;
    Top : Integer;

    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    Picture : TBitmap32;

    constructor Create(AOwner : TBitmap32);
    destructor Destroy; override;
    property Width : Integer read GetWidth;
    property Height : Integer read GetHeight;
    procedure Update;
    procedure Init;
    procedure Die;
    function BoundsRect : TRect;
    property Showing : boolean read _MysteryShipEnabled;
  end;

  TLaserCannon = class
  private
    _LaserCannonCount : Integer;
    _LaserCannonEnabled : Boolean;
    function GetHeight: Integer;
    function GetWidth: Integer;
  protected
    procedure Paint;
  public
    Left : Integer;
    Top : Integer;

    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    Picture : TBitmap32;

    constructor Create(AOwner : TBitmap32);
    destructor Destroy; override;
    property Width : Integer read GetWidth;
    property Height : Integer read GetHeight;
    procedure Update;
    procedure Init;
    procedure Die;
    property Showing : boolean read _LaserCannonEnabled;
  end;

  TEngine = class
  private
    _State: TGameState;
    _PlayerLives: Integer;
    _MainLoop: TJvThreadTimer;
    _KeyQueue: TObjectQueue;
    _LaserCannon: TLaserCannon;
    _MysteryShip : TMysteryShip;
    _BackgroundImage : TBitmap32;
    _FlipFlop : Boolean;
    _FlipFlopCounter : Integer;

    _OnStartGame : TNotifyEvent;
    _OnStopGame : TNotifyEvent;
    _OnPauseGame : TNotifyEvent;
    _OnGameOver : TNotifyEvent;
    _OnUpdateLives : TNotifyEvent;
    _OnUpdateGroundHole : TNotifyEvent;

    procedure Zero(HoleArray : TArrayofBoolean);
    procedure _MainLoopTimer(Sender: TObject);
    procedure SetState(State : TGameState);

    procedure _ProcessKey;
    procedure _UpdateFlipFlop;
    procedure _CheckCollisions;
    procedure _ShootMissile;
    procedure _CheckGameOver;
    procedure _IncPlayerLives;
    procedure _DecPlayerLives;
    procedure _OnGroundHoleHandler(Sender : TObject; var Key: Word; Shift: TShiftState);
    procedure _OnUpdateLivesHandler(Sender : TObject);
  public
    Owner : TBitmap32;

    AlienOrchestrator : TAlienOrchestrator;
    MissileOrchestrator : TMissileOrchestrator;
    ExplosionOrchestrator : TExplosionOrchestrator;
    BunkerOrchestrator : TBunkerOrchestrator;
    ScoreKeeper : TScoreKeeper;
    GroundHoles : TArrayofBoolean;

    constructor Create(AOwner : TBitmap32);
    destructor Destroy; override;

    property OnStartGame : TNotifyEvent read _OnStartGame write _OnStartGame;
    property OnStopGame : TNotifyEvent read _OnStopGame write _OnStopGame;
    property OnPauseGame : TNotifyEvent read _OnPauseGame write _OnPauseGame;
    property OnUpdateLives : TNotifyEvent read _OnUpdateLives write _OnUpdateLives;
    property OnUpdateGroundHole : TNotifyEvent read _OnUpdateGroundHole write _OnUpdateGroundHole;
    property PlayerLives : Integer read _PlayerLives;

    procedure StartGame(Init : boolean = true);
    procedure StopGame;
    procedure PauseGame;
    procedure ProcessKeyDown(Key : Word);
    procedure ProcessKeyUp(Key : Word);

    function GetLaserCannonPosition : TPoint;
  end;

var
  DeviceContext : HDC;

implementation

uses Utilities, Dialogs;

{ TEngine }

constructor TEngine.Create(AOwner : TBitmap32);
begin
  Randomize();

  Owner := AOwner;

  _LaserCannon := TLaserCannon.Create(Owner);
  _LaserCannon.GraphicContext := Owner;
  _MysteryShip := TMysteryShip.Create(Owner);
  _MysteryShip.GraphicContext := Owner;
  MissileOrchestrator := TMissileOrchestrator.Create;
  MissileOrchestrator.OnGroundHole := _OnGroundHoleHandler;
  ExplosionOrchestrator := TExplosionOrchestrator.Create;
  AlienOrchestrator := TAlienOrchestrator.Create(Self);
  AlienOrchestrator.MissileOrchestrator := MissileOrchestrator;
  AlienOrchestrator.ExplosionOrchestrator := ExplosionOrchestrator;
  BunkerOrchestrator := TBunkerOrchestrator.Create;;
  BunkerOrchestrator.ExplosionOrchestrator := ExplosionOrchestrator;
  ScoreKeeper := TScoreKeeper.Create;
  ScoreKeeper.OnUpdateLives := _OnUpdateLivesHandler;
  _KeyQueue := TObjectQueue.Create;

  _BackgroundImage := TBitmap32.Create;
  with _BackgroundImage do begin
    Width := 482;
    Height := 461;
    LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/earth.bmp');
  end;

  _MainLoop := TJvThreadTimer.Create(nil);
  _MainLoop.OnTimer := _MainLoopTimer;
  _MainLoop.Priority := tpHigher;
  if GameSettings.FPS>0 then begin
    _MainLoop.Interval := 1000 div GameSettings.FPS;
  end else begin
    _MainLoop.Interval := 50;
  end;
  _MainLoop.KeepAlive := true;
  _MainLoop.Enabled := true;

  SetLength(GroundHoles, GameSettings.WindowWidth);
end;

destructor TEngine.Destroy;
begin
  SetLength(GroundHoles, 0);

//  _MainLoop.Thread.Suspend;
//  while not _MainLoop.Thread.Suspended do ;
  
  _MainLoop.Free;

  _BackgroundImage.Free;
  _KeyQueue.Free;
  ScoreKeeper.Free;
  ExplosionOrchestrator.Free;
  MissileOrchestrator.Free;
  AlienOrchestrator.Free;
  BunkerOrchestrator.Free;
  _MysteryShip.Free;
  _LaserCannon.Free;

  inherited;
end;

function TEngine.GetLaserCannonPosition: TPoint;
begin
  result := Classes.Point(_LaserCannon.Left, _LaserCannon.Top);
end;

procedure TEngine.PauseGame;
begin
  SetState(gsPaused);
end;

procedure TEngine.ProcessKeyDown(Key: Word);
begin
  if _KeyQueue.Count=0 then begin
    _KeyQueue.Push(TObject(Key));
  end;
end;

procedure TEngine.ProcessKeyUp(Key: Word);
begin

end;

procedure TEngine.SetState(State: TGameState);
var
  OldState : TGameState;
begin
  OldState := _State;
  _State := State; // The new game state

  case OldState of
    gsStopped: case _State of
      gsStopped: {Do nothing};
      gsRunning: begin
        while _KeyQueue.Count>0 do _KeyQueue.Pop;
        _State := gsRunning;
        _PlayerLives := GameSettings.InitialPlayerLives;
        _LaserCannon.Left := 8;
        Zero(GroundHoles);
        if Assigned(_OnStartGame) then begin
          _OnStartGame(Self);
        end;
        if Assigned(_OnUpdateLives) then _OnUpdateLives(Self);
      end;
      gsPaused: {Do nothing};
    end;
    gsRunning: case _State of
      gsStopped: begin
        _State := gsStopped;
        ExplosionOrchestrator.Clear;
        MissileOrchestrator.Clear;
        ScoreKeeper.Clear;
        ShowMessage('   Game Over   ');
//        SetState(gsStopped); // todo: Make this work
        if Assigned(_OnStopGame) then _OnStopGame(Self);
      end;
      gsRunning: {Do nothing};
      gsPaused: begin
        _State := gsPaused;
        if Assigned(_OnPauseGame) then _OnPauseGame(Self);
      end;
    end;
    gsPaused: case _State of
      gsStopped: begin
        _State := gsStopped;
        ExplosionOrchestrator.Clear;
        MissileOrchestrator.Clear;
        ScoreKeeper.Clear;
        if Assigned(_OnStopGame) then _OnStopGame(Self);
      end;
      gsRunning: begin
        while _KeyQueue.Count>0 do _KeyQueue.Pop;
        _State := gsRunning;
        if Assigned(_OnStartGame) then begin
          _OnStartGame(Self);
        end;
      end;
      gsPaused: {Do nothing};
    end;
  end;
end;

procedure TEngine.StartGame(Init : boolean = true);
begin
  if Init then begin
    AlienOrchestrator.Init(Owner);
    BunkerOrchestrator.Init(Owner);
    _MysteryShip.Init;
    _LaserCannon.Init;    
  end;
  
  SetState(gsRunning);
end;

procedure TEngine.StopGame;
begin
  SetState(gsStopped);
end;

procedure TEngine.Zero(HoleArray: TArrayofBoolean);
var
  i : Integer;
begin
  for i := 0 to Length(HoleArray) - 1 do HoleArray[i] := false;
end;

procedure TEngine._CheckGameOver;
var
  x, y : Integer;
  alienCount : Integer;
begin
  // Check if player lives is diminished
  if _PlayerLives<=0 then begin
    StopGame;
    exit;
  end;

  // Check if any aliens are available
  alienCount := 0;
  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if AlienOrchestrator.Map2D[x,y]<>nil then begin
        if AlienOrchestrator.Map2D[x,y].Visible then begin
          alienCount := alienCount + 1;
        end;
      end;
    end;
  end;
  if alienCount=0 then begin
    StartGame;
    exit;
  end;

  // Check if an alien reached the ground
  for y := GameSettings.AlienMeshHeight downto 1 do begin
    for x := 1 to GameSettings.AlienMeshWidth do begin
      if AlienOrchestrator.Map2D[x,y]<>nil then begin
        if AlienOrchestrator.Map2D[x,y].Visible then begin
          if (AlienOrchestrator.Map2D[x,y].Top+AlienOrchestrator.Map2D[x,y].Height)>=_LaserCannon.Top then begin
            StopGame;
            exit;
          end;
        end;
      end;
    end;
  end;
end;

procedure TEngine._DecPlayerLives;
begin
  _PlayerLives := _PlayerLives - 1;
  if _PlayerLives<=0 then begin
    _PlayerLives := 0; // Normalize stuff just in case
  end;

  if Assigned(_OnUpdateLives) then _OnUpdateLives(Self);
end;

procedure TEngine._IncPlayerLives;
begin
  _PlayerLives := _PlayerLives + 1;

  if Assigned(_OnUpdateLives) then _OnUpdateLives(Self);
end;

procedure TEngine._MainLoopTimer(Sender: TObject);
var
  str : string;
  strSize : TSize;
begin
  str := 'PAUSED'; // LOCALIZE:

  _MainLoop.Thread.Suspend;
  try
    _ProcessKey;
    _UpdateFlipFlop;

    if (_State=gsRunning) or (_State=gsPaused) then begin
      try
        if _State=gsRunning then begin
          _LaserCannon.Update;
          ExplosionOrchestrator.Update;
          MissileOrchestrator.Update; // UpdatePlayer
          if _LaserCannon.Showing then begin
            AlienOrchestrator.Update; // UpdateAliens
          end;
          BunkerOrchestrator.Update;
          _MysteryShip.Update;
        end else begin
          If _FlipFlop then begin
            SetTextColor(DeviceContext, ColorToRGB(clWhite));
            SetBkColor(DeviceContext, ColorToRGB(clBlack));
            Windows.GetTextExtentPoint32(DeviceContext, PChar(str), Length(str), strSize);
            TextOut(
              DeviceContext,
              (GameSettings.WindowWidth - strSize.cx) div 2,
              0,
              PChar(str),
              length(str)
            );
          end;
        end;

        Owner.Clear(clBlack32);
        Owner.Draw(Owner.BoundsRect, _BackgroundImage.BoundsRect, _BackgroundImage);
        _LaserCannon.Paint;
        ExplosionOrchestrator.Paint;
        MissileOrchestrator.Paint; // UpdatePlayer
        AlienOrchestrator.Paint; // UpdateAliens
        BunkerOrchestrator.Paint;
        _MysteryShip.Paint;

      finally

      end;

      if _State=gsRunning then begin
        _CheckCollisions;
        _CheckGameOver;
      end;
    end;
  finally
    _MainLoop.Thread.Resume;
  end;
end;

procedure TEngine._OnGroundHoleHandler(Sender : TObject; var Key: Word; Shift: TShiftState);
begin
  GroundHoles[Key] := true;
  If Assigned(_OnUpdateGroundHole) then _OnUpdateGroundHole(Self);
end;

procedure TEngine._OnUpdateLivesHandler(Sender: TObject);
begin
  _IncPlayerLives;
end;

procedure TEngine._ProcessKey;
var
  Key : Word;
begin
  if _KeyQueue.Count=0 then exit;

  Key := Word(_KeyQueue.Pop);
  case _State of
    gsStopped: begin
      if Key=32 then begin
        StartGame;
      end;
      exit;
    end;
    gsRunning: begin
      if _LaserCannon.Showing then begin
        case Key of
          37 : _LaserCannon.Left := _LaserCannon.Left - GameSettings.HorizontalPixelShift * 2;
          39 : _LaserCannon.Left := _LaserCannon.Left + GameSettings.HorizontalPixelShift * 2;
          32 : _ShootMissile;
          ord('p'),ord('P'),19 : PauseGame;
          ord('q'),ord('Q') : StopGame;
        end;

        if _LaserCannon.Left<8 then _LaserCannon.Left := 8;
        if _LaserCannon.Left>(GameSettings.WindowWidth-36) then _LaserCannon.Left := GameSettings.WindowWidth-36;
      end;
      exit;
    end;
    gsPaused: begin
      case Key of
        ord('p'),ord('P'),19 : StartGame(false);
        ord('q'),ord('Q') : StopGame;
      end;
      exit;
    end;
  end;
end;

procedure TEngine._CheckCollisions;
var
  x: Integer;
  y: Integer;
  I: Integer;
  j: Integer;
  Explosion : TExplosion;
begin
  // Check missile/alien collision
  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      for I := 0 to MissileOrchestrator.PlayerObjectList.Count - 1 do begin
        if TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).MissileType=mtPlayer then begin
          if AlienOrchestrator.Map2D[x,y]<>nil then begin
            if AlienOrchestrator.Map2D[x,y].Visible then begin
              if TUtility.PtInRect(Rect(
                AlienOrchestrator.Map2D[x,y].Left + ALIEN_CLEARANCE,
                AlienOrchestrator.Map2D[x,y].Top,
                AlienOrchestrator.Map2D[x,y].Left + AlienOrchestrator.Map2D[x,y].Width - ALIEN_CLEARANCE, // The trick to allowing missiles to pass in between aliens
                AlienOrchestrator.Map2D[x,y].Top + AlienOrchestrator.Map2D[x,y].Height
              ), Classes.Point(TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Left,
                TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Top
              )) then begin
                // Update score
                case AlienOrchestrator.Map2D[x,y].Specie of
                  asAlpha : begin ScoreKeeper.PlayerScore1 := ScoreKeeper.PlayerScore1 + GameSettings.AlienScoreAlpha;
                    AlienOrchestrator.Accelerate;
                  end;
                  asBeta : begin ScoreKeeper.PlayerScore1 := ScoreKeeper.PlayerScore1 + GameSettings.AlienScoreBeta;
                    AlienOrchestrator.Accelerate;
                  end;
                  asGamma : begin ScoreKeeper.PlayerScore1 := ScoreKeeper.PlayerScore1 + GameSettings.AlienScoreGamma;
                    AlienOrchestrator.Accelerate;
                  end;
                end;
                // Obliterate alien
                AlienOrchestrator.Map2D[x,y].Die;
                Explosion := TExplosion.Create(Owner, etAlien);
                Explosion.Left := TUtility.SpriteCenter(
                  AlienOrchestrator.Map2D[x,y].Width,
                  Explosion.Width,
                  AlienOrchestrator.Map2D[x,y].Left
                );
                Explosion.Top := TUtility.SpriteMiddleAlign(AlienOrchestrator.Map2D[x,y].Height, Explosion.Height, AlienOrchestrator.Map2D[x,y].Top);
                ExplosionOrchestrator.AddExplosion(Explosion);

                // Recycle missile
                TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Garbage;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  // Check missile/cannon collision
  if _LaserCannon.Showing then begin
    for I := 0 to MissileOrchestrator.AlienObjectList.Count - 1 do begin
      if TMissile(MissileOrchestrator.AlienObjectList.Items[i]).MissileType=mtAlien then begin
        if TUtility.PtInRect(Rect(
          _LaserCannon.Left,
          _LaserCannon.Top,
          _LaserCannon.Left + _LaserCannon.Width,
          _LaserCannon.Top + _LaserCannon.Height
        ), Classes.Point(TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Left,
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Top+
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Height
        )) then begin
          _LaserCannon.Die;

          Explosion := TExplosion.Create(Owner, etPlayer);
          Explosion.Left := TUtility.SpriteCenter(
            _LaserCannon.Width,
            Explosion.Width,
            _LaserCannon.Left
          );
          Explosion.Top := TUtility.SpriteBottomAlign(_LaserCannon.Height, Explosion.Height, _LaserCannon.Top);
          ExplosionOrchestrator.AddExplosion(Explosion);

          _DecPlayerLives;
          // Recycle missile
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Garbage;
          TUtility.PlayWave('lasercannon_explosion');
        end;
      end;
    end;
  end;

  // Check missile/missile collision
  for I := MissileOrchestrator.AlienObjectList.Count - 1 downto 0 do begin
    for j := MissileOrchestrator.PlayerObjectList.Count - 1 downto 0 do begin
      if TUtility.Overlaps(
        TMissile(MissileOrchestrator.AlienObjectList.Items[i]).BoundsRect,
        TMissile(MissileOrchestrator.PlayerObjectList.Items[j]).BoundsRect
      ) then begin
        Explosion := TExplosion.Create(Owner, etMissile);
        Explosion.Left := TUtility.SpriteCenter(
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Width,
          Explosion.Width,
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Left
        );
        
        Explosion.Top := TUtility.SpriteMiddleAlign(TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Height, Explosion.Height, TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Top);
        ExplosionOrchestrator.AddExplosion(Explosion);
        TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Garbage;
        TMissile(MissileOrchestrator.PlayerObjectList.Items[j]).Garbage;
        break;
      end;
    end;
  end;

  // Check missile/mystership collision
  if _MysteryShip.Showing then begin
    for i := MissileOrchestrator.PlayerObjectList.Count - 1 downto 0 do begin
      if TUtility.Overlaps(
        TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).BoundsRect,
        _MysteryShip.BoundsRect
      ) then begin
        // Update score
        ScoreKeeper.PlayerScore1 := ScoreKeeper.PlayerScore1 + GameSettings.AlienScoreMysteryShip;

        // Obliterate mystery ship
        Explosion := TExplosion.Create(Owner, etMysteryShip);
        Explosion.Left := TUtility.SpriteCenter(
          _MysteryShip.Width,
          Explosion.Width,
          _MysteryShip.Left
        );
        Explosion.Top := TUtility.SpriteMiddleAlign(_MysteryShip.Height, Explosion.Height, _MysteryShip.Top);

        _MysteryShip.Die;
        ExplosionOrchestrator.AddExplosion(Explosion);
        break;
      end;
    end;
  end;

  // Check missile/bunker collision
  for I := 0 to MissileOrchestrator.AlienObjectList.Count - 1 do begin
    if TMissile(MissileOrchestrator.AlienObjectList.Items[i]).MissileType=mtAlien then begin
      for j := low(BunkerOrchestrator.Map) to high(BunkerOrchestrator.Map) do begin
        if TUtility.PtInRect(BunkerOrchestrator.Map[j].BoundsRect, Classes.Point(TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Left,
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Top+
          TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Height
        )) then begin

          if not BunkerOrchestrator.Map[j].Passable(TMissile(MissileOrchestrator.AlienObjectList.Items[i]).BoundsRect, mdMovingDown) then begin
            Explosion := TExplosion.Create(Owner, etGround);
            Explosion.Left := TUtility.SpriteCenter(
              TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Width,
              Explosion.Width,
              TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Left
            );
            Explosion.Top := GameSettings.WindowHeight - Explosion.Height;
            ExplosionOrchestrator.AddExplosion(Explosion);

            // Recycle missile
            TMissile(MissileOrchestrator.AlienObjectList.Items[i]).Garbage;

            // NOTICE: Do not play any waves here
          end;
        end;
      end;
    end;
  end;

  // Check lasermissile/bunker collision
  for i := MissileOrchestrator.PlayerObjectList.Count - 1 downto 0 do begin
    for j := 1 to BunkerOrchestrator.Count do begin
      if TUtility.Overlaps(
        TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).BoundsRect,
        BunkerOrchestrator.Map[j].BoundsRect
      ) then begin
        if not BunkerOrchestrator.Map[j].Passable(TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).BoundsRect, mdMovingUp) then begin
          Explosion := TExplosion.Create(Owner, etGround);
          Explosion.Left := TUtility.SpriteCenter(
            TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Width,
            Explosion.Width,
            TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Left
          );
          Explosion.Top := BunkerOrchestrator.Map[j].Top + BunkerOrchestrator.Map[j].Height;
          ExplosionOrchestrator.AddExplosion(Explosion);

          // Recycle missile
          TMissile(MissileOrchestrator.PlayerObjectList.Items[i]).Garbage;

          // NOTICE: Do not play any waves here          
        end;
      end;
    end;
  end;
end;

procedure TEngine._ShootMissile;
var
  Missile : TMissile;
begin
  if MissileOrchestrator.PlayerMissileCount < GameSettings.MaxPlayerMissileCount then begin
    Missile := TMissile.Create(Owner);
    Missile.GraphicContext := Owner;
    Missile.Left := _LaserCannon.Left + _LaserCannon.Width div 2;
    Missile.Top := _LaserCannon.Top;
    Missile.ExplosionOrchestrator := ExplosionOrchestrator;
    MissileOrchestrator.AddMissile(Missile);
    TUtility.PlayWave('player_missile_shoot');
  end;
end;

procedure TEngine._UpdateFlipFlop;
begin
  _FlipFlopCounter := _FlipFlopCounter + 1;
  case _FlipFlopCounter of
    0..3 : _FlipFlop := true;
    4..7 : _FlipFlop := false;
  else
    _FlipFlopCounter := 0;
  end;
end;

{ TLaserCannon }

constructor TLaserCannon.Create(AOwner: TBitmap32);
begin
  Owner := AOwner;
  GraphicContext := AOwner;
  Picture := TBitmap32.Create;
  Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/lasercannon.bmp');
  Picture.DrawMode := dmBlend;  
  Top := AOwner.Height - trunc(48 * 1.5);
end;

destructor TLaserCannon.Destroy;
begin
  Picture.Free;
  inherited;
end;

procedure TLaserCannon.Die;
begin
  _LaserCannonEnabled := false;
end;

function TLaserCannon.GetHeight: Integer;
begin
  result := Picture.Height;
end;

function TLaserCannon.GetWidth: Integer;
begin
  result := Picture.Width;
end;

procedure TLaserCannon.Init;
begin
  _LaserCannonCount := 0;
  _LaserCannonEnabled := true;
end;

procedure TLaserCannon.Paint;
begin
  if not _LaserCannonEnabled then exit;

  GraphicContext.Draw(Self.Left, Self.Top, Picture);
end;

procedure TLaserCannon.Update;
begin
  if not(_LaserCannonEnabled) then begin
    _LaserCannonCount := _LaserCannonCount + 1;

    If _LaserCannonCount >= 100 then _LaserCannonEnabled := true;
  end;
end;

{ TMysteryShip }

function TMysteryShip.BoundsRect: TRect;
begin
  result := Rect(Self.Left, Self.Top, Self.Width + Self.Left, Self.Top + Self.Height);
end;

constructor TMysteryShip.Create(AOwner: TBitmap32);
begin
  Owner := AOwner;
  GraphicContext := AOwner;
  Picture := TBitmap32.Create;
  Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/mysteryship.bmp');
  Picture.DrawMode := dmBlend;  
  Top := 8;

  _MysteryShipThreshold := trunc(1000 / GameSettings.FPS * GameSettings.MysteryShipFrequency);
end;

destructor TMysteryShip.Destroy;
begin
  Picture.Free;

  inherited;
end;

procedure TMysteryShip.Die;
begin
  TUtility.PlayWave('mysteryship_explosion');
  Self.Init;
end;

function TMysteryShip.GetHeight: Integer;
begin
  result := Picture.Height;
end;

function TMysteryShip.GetWidth: Integer;
begin
  result := Picture.Width;
end;

procedure TMysteryShip.Init;
begin
  Self._Direction := TMysteryShipDirection(Random(2));
  case Self._Direction of
    msdLeft: Self.Left := GameSettings.WindowWidth;
    msdRight: Self.Left := -1 * Self.Width;
  end;
  Self._MysteryShipCount := 0;
  Self._MysteryShipEnabled := false;
end;

procedure TMysteryShip.Paint;
begin
  GraphicContext.Draw(Self.Left, Self.Top, Picture);
end;

procedure TMysteryShip.Update;
begin
  if not(_MysteryShipEnabled) then begin
    _MysteryShipCount := _MysteryShipCount + 1;
    if _MysteryShipCount>=_MysteryShipThreshold then begin
      Self._Direction := TMysteryShipDirection(Random(2));
      case Self._Direction of
        msdLeft: Self.Left := GameSettings.WindowWidth;
        msdRight: Self.Left := -1 * Self.Width;
      end;
      TUtility.PlayWave('mysteryship_cruise', true);
      _MysteryShipEnabled := true;
    end;
  end else begin
    case Self._Direction of
      msdLeft:
        begin
          Self.Left := Self.Left - GameSettings.HorizontalPixelShift;
          if Self.Left <= -1 * Self.Width then begin
            _MysteryShipEnabled := false;
            _MysteryShipCount := 0;
          end;
        end;
      msdRight:
        begin
          Self.Left := Self.Left + GameSettings.HorizontalPixelShift;
          if Self.Left >= GameSettings.WindowWidth then begin
            _MysteryShipEnabled := false;
            _MysteryShipCount := 0;
          end;
        end;
    end;
  end;
end;

end.
