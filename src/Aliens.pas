unit Aliens;

interface

uses
  Controls, ExtCtrls, Classes, Settings, Missiles, Graphics,
  Windows, Explosions, GR32_Image, GR32;

type
  TAlienSpecie = (asAlpha, asBeta, asGamma);
  TAlienDirection = (adLeft, adRight);

  TAlienOrchestrator = class;

  TAlien = class
  private
    _Frame : Integer;
    _MissileOrchestrator : TMissileOrchestrator;
    _AlienOrchestrator : TAlienOrchestrator;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    _Specie : TAlienSpecie;
    procedure FlipDirection;
    procedure Descend;
    procedure _SetSpecie(const Value: TAlienSpecie);
    function GetHeight: Integer;
    function GetWidth: Integer;
  protected
    procedure Paint;
  public
    Top : Integer;
    Left : Integer;
    Visible : Boolean;
    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    Picture : TBitmap32;

    Direction : TAlienDirection;
    constructor Create(AOwner: TBitmap32);
    destructor Destroy; override;
    property Specie : TAlienSpecie read _Specie write _SetSpecie;
    property Width : Integer read GetWidth;
    property Height : Integer read GetHeight;
    procedure UpdateMotion;
    procedure ShootMissile;
    procedure Die;
  end;

  TAlienMap =  Array[1..11,1..5] of TAlien;

  TAlienOrchestrator = class
  private
    _ThresholdCount : Integer;
    _Map2D : TAlienMap;
    _MissileOrchestrator : TMissileOrchestrator;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    _AccelerateX : Double;
    _AccelerateY : Double;
    _FlipFlop : Boolean;
    _Engine : TObject;
    function GetAlienCount: Integer;
    procedure _UpdateFlipFlop;
  public
    constructor Create(Engine : TObject);
    destructor Destroy; override;

    property Map2D : TAlienMap read _Map2D write _Map2D;
    property MissileOrchestrator : TMissileOrchestrator read _MissileOrchestrator write _MissileOrchestrator;
    property ExplosionOrchestrator : TExplosionOrchestrator read _ExplosionOrchestrator write _ExplosionOrchestrator;
    procedure Accelerate;
    procedure Init(AOwner : TBitmap32);
    procedure Update;
    procedure Paint;
    procedure DetectAnomalies;
    property Count : Integer read GetAlienCount;
  end;

implementation

uses Engine, Utilities, Math;

{ TAlien }

constructor TAlien.Create(AOwner: TBitmap32);
begin
  Owner := AOwner;
  GraphicContext := AOwner;
  Picture := TBitmap32.Create;
  Picture.DrawMode := dmBlend;

  Specie := asAlpha;
end;

procedure TAlien.Descend;
begin
  Self.Top := Self.Top + GameSettings.VerticalPixelShift;
end;

destructor TAlien.Destroy;
begin
  Picture.Free;
  inherited;  
end;

procedure TAlien.Die;
begin
  TUtility.PlayWave('alien_explosion');
  Self.Visible := false;
end;

procedure TAlien.FlipDirection;
begin
  if Direction=adLeft then Direction := adRight
  else Direction := adLeft;
end;

function TAlien.GetHeight: Integer;
begin
  result := Picture.Height;
end;

function TAlien.GetWidth: Integer;
begin
  result := Picture.Width;
end;

procedure TAlien.Paint;
begin
  GraphicContext.Draw(Self.Left, Self.Top, Picture);
end;

procedure TAlien.ShootMissile;
var
  Missile : TMissile;
begin
  If Visible then begin
    Missile := TMissile.Create(Self.GraphicContext);
    Missile.GraphicContext := Self.GraphicContext;
    Missile.Left := Self.Left + Self.Width div 2;
    Missile.Top := Self.Top + Self.Height;
    Missile.MissileType := mtAlien;
    Missile.ExplosionOrchestrator := _ExplosionOrchestrator;

    _MissileOrchestrator.AddMissile(Missile);
  end;
end;

procedure TAlien.UpdateMotion;
begin
  case Self.Direction of
    adLeft: Self.Left := trunc(Self.Left - GameSettings.HorizontalPixelShift);
    adRight: Self.Left := trunc(Self.Left + GameSettings.HorizontalPixelShift);
  end;

  case _Frame of
    0 :
      case _Specie of
        asAlpha: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_alpha_1.bmp');
        asBeta: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_beta_1.bmp');
        asGamma: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_gamma_1.bmp');
      end;
    4 :
      case _Specie of
        asAlpha: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_alpha_2.bmp');
        asBeta: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_beta_2.bmp');
        asGamma: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_gamma_2.bmp');
      end;
  end;
  inc(_Frame);
  if _Frame>8 then _Frame := 0;

  if Self.Left<=8 then begin
    FlipDirection;
  end else
  if Self.Left>=(GameSettings.WindowWidth-36) then begin
    FlipDirection;
  end;
end;

procedure TAlien._SetSpecie(const Value: TAlienSpecie);
begin
  _Specie := Value;
  case _Specie of
    asAlpha: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_alpha_1.bmp');
    asBeta: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_beta_1.bmp');
    asGamma: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/alien_gamma_1.bmp');
  end;
end;

{ TAlienOrchestrator }

procedure TAlienOrchestrator.Accelerate;
begin
  _AccelerateX := _AccelerateX + GameSettings.XAxisAcceleration;
  _AccelerateY := _AccelerateY + GameSettings.YAxisAcceleration;
end;

constructor TAlienOrchestrator.Create(Engine : TObject);
begin
  // Nothing here yet
  _ThresholdCount := 0;
  _Engine := TEngine(Engine);
end;

procedure TAlienOrchestrator.Init(AOwner : TBitmap32);
var
  x: Integer;
  y: Integer;
begin
  _AccelerateX := 0;
  _AccelerateY := 0;
  _ThresholdCount := 0;

  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if Assigned(_Map2D[x,y]) then begin
        // We are reusing the previous alien object
        _Map2D[x,y].Visible := true;
      end else begin
        _Map2D[x,y] := TAlien.Create(AOwner);
        _Map2D[x,y]._MissileOrchestrator := _MissileOrchestrator;
        _Map2D[x,y]._AlienOrchestrator := Self;
        _Map2D[x,y].GraphicContext := AOwner;
        _Map2D[x,y]._ExplosionOrchestrator := _ExplosionOrchestrator;
        case y of
          4,5 : _Map2D[x,y].Specie := asAlpha;
          2,3 : _Map2D[x,y].Specie := asBeta;
        else
          _Map2D[x,y].Specie := asGamma;
        end;
      end;
      _Map2D[x,y].Left := x * 32;
      _Map2D[x,y].Top := trunc(y * 32); // Initial height of the alien mesh
    end;
  end;
end;

procedure TAlienOrchestrator.Paint;
var
  x: Integer;
  y: Integer;
begin
  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if _Map2D[x,y]<>nil then begin
        if _Map2D[x,y].Visible then begin
          _Map2D[x,y].Paint;
        end;
      end;
    end;
  end;
end;

destructor TAlienOrchestrator.Destroy;
var
  x, y : integer;
begin
  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if Assigned(_Map2D[x,y]) then begin
        _Map2D[x,y].Free;;
      end;
    end;
  end;

  inherited;
end;

procedure TAlienOrchestrator.DetectAnomalies;
var
  x: Integer;
  y: Integer;
  LeftYes,
  RightYes : Integer;
begin
  LeftYes := 0;
  RightYes := 0;

  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if _Map2D[x,y]<>nil then begin
        if _Map2D[x,y].Visible then begin
          case _Map2D[x,y].Direction of
            adLeft : Inc(LeftYes);
            adRight : Inc(RightYes);
          end;
        end;
      end;
    end;
  end;
  if LeftYes=0 then exit;
  if RightYes=0 then exit;
  if LeftYes>RightYes then begin
    for x := 1 to GameSettings.AlienMeshWidth do begin
      for y := 1 to GameSettings.AlienMeshHeight do begin
        if _Map2D[x,y]<>nil then begin
          if _Map2D[x,y].Visible then begin
            _Map2D[x,y].Direction := adRight;
            _Map2D[x,y].Descend;
          end;
        end;
      end;
    end;
  end else begin
    for x := 1 to GameSettings.AlienMeshWidth do begin
      for y := 1 to GameSettings.AlienMeshHeight do begin
        if _Map2D[x,y]<>nil then begin
          if _Map2D[x,y].Visible then begin
            _Map2D[x,y].Direction := adLeft;
            _Map2D[x,y].Descend;
          end;
        end;
      end;
    end;
  end;
end;

function TAlienOrchestrator.GetAlienCount: Integer;
var
  x, y : Integer;
begin
  result := 0;
  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if _Map2D[x,y]<>nil then begin
        if _Map2D[x,y].Visible then begin
          inc(result);
        end;
      end;
    end;
  end;
end;

procedure TAlienOrchestrator._UpdateFlipFlop;
begin
  _FlipFlop := not(_FlipFlop);
end;

procedure TAlienOrchestrator.Update;
var
  x: Integer;
  y: Integer;
  LaserCanon : TPoint;
  distance : Extended;

  memDist : Extended;
  memAlien : TPoint;
begin
  _ThresholdCount := _ThresholdCount + 1;
  if _ThresholdCount>5 then _ThresholdCount := 0;

  _UpdateFlipFlop;

  for x := 1 to GameSettings.AlienMeshWidth do begin
    for y := 1 to GameSettings.AlienMeshHeight do begin
      if _Map2D[x,y]<>nil then begin
        if _Map2D[x,y].Visible then begin
          if _ThresholdCount mod 6 = 0 then begin
            _Map2D[x,y].UpdateMotion;
          end;
        end;
      end;
    end;
  end;

  memDist := MaxExtended;
  memAlien := Point(0,0);

  if _MissileOrchestrator.AlienMissileCount<GameSettings.MaxAlienMissileCount then begin
    if _FlipFlop then begin
      _Map2d[Random(GameSettings.AlienMeshWidth)+1,
        Random(GameSettings.AlienMeshHeight)+1].ShootMissile;
    end else begin
      LaserCanon := TEngine(_Engine).GetLaserCannonPosition;
      for x := 1 to GameSettings.AlienMeshWidth do begin
        for y := 1 to GameSettings.AlienMeshHeight do begin
          if _Map2D[x,y]<>nil then begin
            if _Map2D[x,y].Visible then begin
              distance := floor(sqrt(power((_Map2D[x,y].Left - LaserCanon.X),2)+power((_Map2D[x,y].Top - LaserCanon.Y),2)));
              if distance<memDist then begin
                memDist := distance;
                memAlien := Point(x,y);
              end;
            end;
          end;
        end;
      end;

      if not(PointsEqual(memAlien, Point(0,0))) then begin
        _Map2d[memAlien.X, memAlien.Y].ShootMissile;
      end;
    end;
  end;

  DetectAnomalies;
end;

end.