unit Missiles;

interface

uses
  ExtCtrls, Classes, Contnrs, Graphics, Controls, Windows, Explosions, GR32_Image, GR32;

type
  TMissileType = (mtPlayer, mtAlien);

  TMissileOrchestrator = class;

  TMissile = class
  private
    _Garbage : Boolean;
    _Drawing : Boolean;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    _MissileOrchestrator : TMissileOrchestrator;
  protected
    procedure Paint;
  public
    MissileType : TMissileType;
    Top : Integer;
    Left : Integer;
    Width : Integer;
    Height : Integer;
    BrushColor : TColor32;
    PenColor : TColor32;
    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    function BoundsRect : TRect;
    constructor Create(AOwner: TBitmap32);
    procedure UpdateMotion;
    procedure Garbage;
    property ExplosionOrchestrator : TExplosionOrchestrator read _ExplosionOrchestrator write _ExplosionOrchestrator;
  end;

  TMissileOrchestrator = class
  private
    _AlienObjectList : TObjectList;
    _PlayerObjectList : TObjectList;
    _OnGroundHole : TKeyEvent;
    function GetItem(Index: Integer): TObject;
    procedure SetItem(Index: Integer; const Value: TObject);
    function GetAlienMissileCount: Integer;
    function GetPlayerMissileCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure Update;
    procedure Paint;
    procedure AddMissile(Missile : TMissile);
    procedure TakeOutTheTrash;
    property AlienMissileCount : Integer read GetAlienMissileCount;
    property PlayerMissileCount : Integer read GetPlayerMissileCount;
    property AlienItems[Index: Integer]: TObject read GetItem write SetItem;
    property AlienObjectList : TObjectList read _AlienObjectList write _AlienObjectList;
    property PlayerObjectList : TObjectList read _PlayerObjectList write _PlayerObjectList;
    procedure RegisterHole(Position : Word);
    property OnGroundHole : TKeyEvent read _OnGroundHole write _OnGroundHole;
  end;

implementation

uses Settings, Engine, Utilities;

{ TMissile }

function TMissile.BoundsRect: TRect;
begin
  result := Rect(Self.Left, Self.Top, Self.Width + Self.Left, Self.Top + Self.Height);
end;

constructor TMissile.Create(AOwner: TBitmap32);
begin
  Owner := AOwner;
  GraphicContext := AOwner;

  Width := 2;
  Height := 8;

  BrushColor := clWhite32;
  PenColor := clWhite32;
end;

procedure TMissile.Garbage;
begin
  _Garbage := true;
end;

procedure TMissile.Paint;
var
  Save: Boolean;                
begin
  if _Garbage then exit;

  try
      Save := _Drawing;
      _Drawing := True;
      try
        GraphicContext.FrameRectS(BoundsRect, clWhite32);
      finally
        _Drawing := Save;
      end;
  finally

  end;
end;

procedure TMissile.UpdateMotion;
var
  Explosion : TExplosion;
begin
  case MissileType of
    mtPlayer: begin
      Top := Top - GameSettings.PlayerMissilePixelShift;
      If Top<=0 then begin
        if _ExplosionOrchestrator<>nil then begin
          Explosion := TExplosion.Create(GraphicContext, etSky);
          Explosion.Left := TUtility.SpriteCenter(
            Self.Width,
            Explosion.Width,
            Self.Left
          );
          Explosion.Top := TUtility.SpriteTopAlign(Self.Height, Explosion.Height, Self.Top);
          _ExplosionOrchestrator.AddExplosion(Explosion);
        end;

        Top := 0;
        Garbage;
      end;
    end;
    mtAlien: begin
      Top := Top + GameSettings.AlienMissilePixelShift;
      If Top>=(GameSettings.WindowHeight-48) then begin
        if _ExplosionOrchestrator<>nil then begin
          Explosion := TExplosion.Create(GraphicContext, etGround);
          Explosion.Left := TUtility.SpriteCenter(
            Self.Width,
            Explosion.Width,
            Self.Left
          );
          Explosion.Top := TUtility.SpriteBottomAlign(Self.Height, Explosion.Height, Self.Top);
          _ExplosionOrchestrator.AddExplosion(Explosion);
        end;

        Top := GameSettings.WindowHeight-48;
        Garbage;
        _MissileOrchestrator.RegisterHole(Self.Left);
      end;
    end;
  end;
end;

{ TMissileOrchestrator }

procedure TMissileOrchestrator.AddMissile(Missile: TMissile);
begin
  Missile._MissileOrchestrator := Self;
  case Missile.MissileType of
    mtAlien: _AlienObjectList.Add(Missile);
    mtPlayer: _PlayerObjectList.Add(Missile);
  end;
end;

procedure TMissileOrchestrator.Clear;
begin
  _AlienObjectList.Clear;
  _PlayerObjectList.Clear;
end;

constructor TMissileOrchestrator.Create;
begin
  _AlienObjectList := TObjectList.Create;
  _AlienObjectList.OwnsObjects := true;
  _PlayerObjectList := TObjectList.Create;
  _PlayerObjectList.OwnsObjects := true;
end;

destructor TMissileOrchestrator.Destroy;
begin
  _AlienObjectList.Clear;
  _AlienObjectList.Free;
  _PlayerObjectList.Clear;
  _PlayerObjectList.Free;

  inherited;
end;

function TMissileOrchestrator.GetAlienMissileCount: Integer;
begin
  result := _AlienObjectList.Count;
end;

function TMissileOrchestrator.GetItem(Index: Integer): TObject;
begin
  result := _AlienObjectList.Items[Index];
end;

function TMissileOrchestrator.GetPlayerMissileCount: Integer;
begin
  result := _PlayerObjectList.Count;
end;

procedure TMissileOrchestrator.Paint;
var
  I: Integer;
  Missile : TMissile;
begin
  if _AlienObjectList.Count>0 then begin
    for I := 0 to _AlienObjectList.Count - 1 do begin
      Missile := TMissile(_AlienObjectList.Items[i]);
      Missile.Paint;
    end;
  end;

  if _PlayerObjectList.Count>0 then begin
    for I := 0 to _PlayerObjectList.Count - 1 do begin
      Missile := TMissile(_PlayerObjectList.Items[i]);
      Missile.Paint;
    end;
  end;
end;

procedure TMissileOrchestrator.RegisterHole(Position: Word);
begin
  if Assigned(_OnGroundHole) then _OnGroundHole(Self, Position, [ssShift]);
end;

procedure TMissileOrchestrator.SetItem(Index: Integer; const Value: TObject);
begin
  _AlienObjectList.Items[Index] := Value;
end;

procedure TMissileOrchestrator.TakeOutTheTrash;
var
  I : Integer;
begin
  for I := (_AlienObjectList.Count - 1) downto 0 do begin
    if TMissile(_AlienObjectList.Items[i])._Garbage then begin
      _AlienObjectList.Delete(i);
    end;
  end;

  for I := (_PlayerObjectList.Count - 1) downto 0 do begin
    if TMissile(_PlayerObjectList.Items[i])._Garbage then begin
      _PlayerObjectList.Delete(i);
    end;
  end;
end;

procedure TMissileOrchestrator.Update;
var
  I: Integer;
  Missile : TMissile;
begin
  if _AlienObjectList.Count>0 then begin
    for I := 0 to _AlienObjectList.Count - 1 do begin
      Missile := TMissile(_AlienObjectList.Items[i]);
      Missile.UpdateMotion;
    end;
  end;

  if _PlayerObjectList.Count>0 then begin
    for I := 0 to _PlayerObjectList.Count - 1 do begin
      Missile := TMissile(_PlayerObjectList.Items[i]);
      Missile.UpdateMotion;
    end;
  end;

  TakeOutTheTrash;  
end;

end.