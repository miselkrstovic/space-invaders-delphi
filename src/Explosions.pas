unit Explosions;

interface

uses
  ExtCtrls, Classes, Contnrs, Graphics, Controls, Windows, GR32_Image, GR32;

type
  TExplosionType = (etPlayer, etAlien, etMissile, etMysteryShip, etSky, etGround);

  TExplosionOrchestrator = class;

  TExplosion = class
  private
    _Garbage : Boolean;
    _Frames : Integer;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    _ExplosionType : TExplosionType;    
    function GetHeight: Integer;
    function GetWidth: Integer;
    procedure SetExplosionType(const Value: TExplosionType);
  protected
    procedure Paint;
  public
    Top : Integer;
    Left : Integer;
    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    Picture : TBitmap32;

    function BoundsRect : TRect;
    constructor Create(AOwner: TBitmap32; AExplosionType : TExplosionType);
    destructor Destroy; override;
    procedure UpdateAnimation;
    procedure Garbage;
    property ExplosionType : TExplosionType read _ExplosionType write SetExplosionType;
    property Width : Integer read GetWidth;
    property Height : Integer read GetHeight;    
  end;

  TExplosionOrchestrator = class
  private
    _ExplosionObjectList : TObjectList;
    function GetItem(Index: Integer): TObject;
    procedure SetItem(Index: Integer; const Value: TObject);
    function GetExplosionCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure Update;
    procedure Paint;
    procedure AddExplosion(Explosion : TExplosion);
    procedure TakeOutTheTrash;
    property ExplosionCount : Integer read GetExplosionCount;
    property ExplosionItems[Index: Integer]: TObject read GetItem write SetItem;
    property ExplosionObjectList : TObjectList read _ExplosionObjectList write _ExplosionObjectList;
  end;

implementation

uses Settings, Engine;

{ TExplosion }

function TExplosion.BoundsRect: TRect;
begin
  result := Rect(Self.Left, Self.Top, Self.Width + Self.Left, Self.Top + Self.Height);
end;

constructor TExplosion.Create(AOwner: TBitmap32; AExplosionType : TExplosionType);
begin
  Owner := AOwner;
  GraphicContext := AOwner;
  Picture := TBitmap32.Create;
  Picture.DrawMode := dmBlend;  
  ExplosionType := AExplosionType;
end;

destructor TExplosion.Destroy;
begin
  Picture.Free;
  inherited;
end;

function TExplosion.GetHeight: Integer;
begin
  result := Picture.Height;
end;

function TExplosion.GetWidth: Integer;
begin
  result := Picture.Width;
end;

procedure TExplosion.Garbage;
begin
  _Garbage := true;
end;

procedure TExplosion.Paint;
begin
  Picture.DrawMode := dmBlend;
  GraphicContext.Draw(Self.Left, Self.Top, Picture);
end;

procedure TExplosion.SetExplosionType(const Value: TExplosionType);
begin
  _ExplosionType := Value;
  case _ExplosionType of
    etPlayer: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/explosion.bmp');
    etAlien: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/explosion.bmp');
    etMissile: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/missile_explosion.bmp');
    etMysteryShip: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/mysteryship_explosion.bmp');
    etSky: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/sky_explosion.bmp');
    etGround: Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/ground_explosion.bmp');
  else
    Self.Picture.LoadFromFile({ExtractFilePath(ParamStr(0))+}'bitmaps/explosion.bmp');      
  end;
end;

procedure TExplosion.UpdateAnimation;
begin
  inc(_Frames);
  if _Frames>10 then Garbage;
end;

{ TExplosionOrchestrator }

procedure TExplosionOrchestrator.AddExplosion(Explosion: TExplosion);
begin
  Explosion._ExplosionOrchestrator := Self;
  _ExplosionObjectList.Add(Explosion);
end;

procedure TExplosionOrchestrator.Clear;
begin
  _ExplosionObjectList.Clear;
end;

constructor TExplosionOrchestrator.Create;
begin
  _ExplosionObjectList := TObjectList.Create;
  _ExplosionObjectList.OwnsObjects := true;
end;

destructor TExplosionOrchestrator.Destroy;
begin
  _ExplosionObjectList.Clear;
  _ExplosionObjectList.Free;

  inherited;
end;

function TExplosionOrchestrator.GetExplosionCount: Integer;
begin
  result := _ExplosionObjectList.Count;
end;

function TExplosionOrchestrator.GetItem(Index: Integer): TObject;
begin
  result := _ExplosionObjectList.Items[Index];
end;

procedure TExplosionOrchestrator.Paint;
var
  I: Integer;
  Explosion : TExplosion;
begin
  if _ExplosionObjectList.Count>0 then begin
    for I := 0 to _ExplosionObjectList.Count - 1 do begin
      Explosion := TExplosion(_ExplosionObjectList.Items[i]);
      Explosion.Paint;
    end;
  end;
end;

procedure TExplosionOrchestrator.SetItem(Index: Integer; const Value: TObject);
begin
  _ExplosionObjectList.Items[Index] := Value;
end;

procedure TExplosionOrchestrator.TakeOutTheTrash;
var
  I : Integer;
begin
  for I := (_ExplosionObjectList.Count - 1) downto 0 do begin
    if TExplosion(_ExplosionObjectList.Items[i])._Garbage then begin
      _ExplosionObjectList.Delete(i);
    end;
  end;
end;

procedure TExplosionOrchestrator.Update;
var
  I: Integer;
  Explosion : TExplosion;
begin
  if _ExplosionObjectList.Count>0 then begin
    for I := 0 to _ExplosionObjectList.Count - 1 do begin
      Explosion := TExplosion(_ExplosionObjectList.Items[i]);
      Explosion.UpdateAnimation;
    end;
  end;

  TakeOutTheTrash;
end;

end.