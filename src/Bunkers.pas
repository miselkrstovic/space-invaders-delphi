unit Bunkers;

interface

uses
  Controls, ExtCtrls, Classes, Settings, Missiles, Graphics, Math,
  Windows, Explosions, GR32_Image, GR32;

type
  TBunkerOrchestrator = class;

  TBunkerBitmap = array of array of boolean;

  TMissileDirection = (mdMovingUp, mdMovingDown);

  TBunker = class
  private
    _Bitmap : TBunkerBitmap;
    _BunkerOrchestrator : TBunkerOrchestrator;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    function GetHeight: Integer;
    function GetWidth: Integer;
  protected
    procedure Paint;
  public
    Top : Integer;
    Left : Integer;
    Owner : TBitmap32;
    GraphicContext : TBitmap32;
    Picture : TBitmap32;

    constructor Create(AOwner: TBitmap32);
    destructor Destroy; override;
    property Width : Integer read GetWidth;
    property Height : Integer read GetHeight;
    procedure Update;
    procedure Reset;
    function Passable(MissileRect : TRect; MissileDirection : TMissileDirection) : boolean;
    function BoundsRect : TRect;
  end;

  TBunkerMap =  Array[1..4] of TBunker;

  TBunkerOrchestrator = class
  private
    _Map : TBunkerMap;
    _ExplosionOrchestrator : TExplosionOrchestrator;
    function GetBunkerCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    property Map : TBunkerMap read _Map write _Map;
    property ExplosionOrchestrator : TExplosionOrchestrator read _ExplosionOrchestrator write _ExplosionOrchestrator;
    procedure Init(AOwner : TBitmap32);
    procedure Paint;
    procedure Update;
    property Count : Integer read GetBunkerCount;
  end;

implementation

uses Engine, SysUtils, Dialogs;

{ TBunkerOrchestrator }

constructor TBunkerOrchestrator.Create;
begin

end;

destructor TBunkerOrchestrator.Destroy;
var
  x: Integer;
begin
  for x := low(_Map) to High(_Map) do begin
    if Assigned(_Map[x]) then begin
      _Map[x].Free;
    end;
  end;

  inherited;
end;

function TBunkerOrchestrator.GetBunkerCount: Integer;
begin
  result := high(Map);
end;

procedure TBunkerOrchestrator.Init(AOwner: TBitmap32);
var
  x: Integer;
  segment : Integer;
begin
  segment := GameSettings.WindowWidth div 4;
  
  for x := low(_Map) to High(_Map) do begin
    if Assigned(_Map[x]) then begin
      // We are reusing the previous bunker object
      _Map[x].Picture.PenColor := SetAlpha(clWhite32, $FF);
      _Map[x].Picture.FillRect(0, 0, _Map[x].Width, _Map[x].Height, SetAlpha(clWhite32, $FF));

      _Map[x].Reset;
    end else begin
      _Map[x] := TBunker.Create(AOwner);
      _Map[x]._BunkerOrchestrator := Self;
      _Map[x].GraphicContext := AOwner;
      _Map[x]._ExplosionOrchestrator := _ExplosionOrchestrator;
    end;

    _Map[x].Left := ((segment - _Map[x].Width) div 2) + segment * (x - 1);
    _Map[x].Top := GameSettings.WindowHeight * 69 div 100;
  end;
end;

procedure TBunkerOrchestrator.Paint;
var
  x: Integer;
begin
  for x := low(_Map) to High(_Map) do begin
    if _Map[x]<>nil then begin
      _Map[x].Paint;
    end;
  end;
end;

procedure TBunkerOrchestrator.Update;
begin
  // Nothing
end;

{ TBunker }

function TBunker.BoundsRect: TRect;
begin
  result := Rect(Self.Left, Self.Top, Self.Width + Self.Left, Self.Top + Self.Height);
end;

constructor TBunker.Create(AOwner: TBitmap32);
begin
  Owner := AOwner;
  GraphicContext := AOwner;
  Picture := TBitmap32.Create;
  Picture.Width := 42;
  Picture.Height := 32;
  Picture.MasterAlpha := $FF;
  Picture.DrawMode := dmBlend;
  
  Reset;
end;

destructor TBunker.Destroy;
begin
  Picture.Free;

  inherited;
end;

function TBunker.GetHeight: Integer;
begin
  result := Picture.Height;
end;

function TBunker.GetWidth: Integer;
begin
  result := Picture.Width;
end;

procedure TBunker.Paint;
begin
  GraphicContext.Draw(Self.Left, Self.Top, Picture);
end;

function TBunker.Passable(MissileRect: TRect;
  MissileDirection: TMissileDirection): boolean;
var
  i, j : Integer;
  slotIndex : Integer;
  MissileHeight : Integer;

  function IsValidSlotIndex(Value : Integer) : boolean;
  begin
    result := (Value>=0) and (Value<width);
  end;
begin
  result := true;
  slotIndex := abs(Self.Left - MissileRect.Left);
  if not(IsValidSlotIndex(slotIndex)) then begin
    // todo: Why is slotIndex yielding 42 (Width of the bunker)??
    exit;
  end;

  MissileHeight := MissileRect.Bottom - MissileRect.Top;

  if MissileDirection=mdMovingDown then begin
    for i := 0 to height-1 do begin
      if not(_Bitmap[slotIndex, i]) then begin
        result := false;
        for j := i to Min(i + MissileHeight, Height)- 1 do begin
          // Alien missile explosion is MISSILE_WIDTH x2
          if IsValidSlotIndex(slotIndex-1) then _Bitmap[slotIndex-1, j] := true;
          if IsValidSlotIndex(slotIndex) then _Bitmap[slotIndex, j] := true;
          if IsValidSlotIndex(slotIndex+1) then _Bitmap[slotIndex+1, j] := true;
          if IsValidSlotIndex(slotIndex+2) then _Bitmap[slotIndex+2, j] := true;
        end;

        break;
      end;
    end;

    if not(result) then begin
      Picture.PenColor := SetAlpha(clBlack32, $00);
      Picture.FillRect(
        Max(abs(Self.Left - MissileRect.Left) - 1, 0),
        i,
        Min(abs(Self.Left - MissileRect.Left) + 2 + 1, Picture.Width),
        Min(i + MissileHeight+1, Picture.Height),
        SetAlpha(clBlack32, $00)
      );
      result := false;
      _Bitmap[slotIndex, i] := true;
    end;
  end else begin
    for i := height-1 downto 0 do begin
      if not(_Bitmap[slotIndex, i]) then begin
        result := false;
        for j := Max(i, Height - 1) downto i-MissileHeight do begin
          // LaserCannon missile explosion is MISSILE_WIDTH x4
          if IsValidSlotIndex(slotIndex-2) then _Bitmap[slotIndex-2, j] := true;
          if IsValidSlotIndex(slotIndex-1) then _Bitmap[slotIndex-1, j] := true;
          if IsValidSlotIndex(slotIndex) then _Bitmap[slotIndex, j] := true;
          if IsValidSlotIndex(slotIndex+1) then _Bitmap[slotIndex+1, j] := true;
          if IsValidSlotIndex(slotIndex+2) then _Bitmap[slotIndex+2, j] := true;
          if IsValidSlotIndex(slotIndex+3) then _Bitmap[slotIndex+3, j] := true;
        end;

        break;
      end;
    end;

    if not(result) then begin
      Picture.PenColor := SetAlpha(clBlack32, $00);
      Picture.FillRect(
        Max(abs(Self.Left - MissileRect.Left) - 2, 0),
        Max(i-MissileHeight, 0),
        Min(abs(Self.Left - MissileRect.Left) + 2 + 2, Picture.Width),
        Min(i+1, Picture.Height),
        SetAlpha(clBlack32, $00)
      );
      result := false;
      _Bitmap[slotIndex, i] := true;
    end;
  end;
end;

procedure TBunker.Reset;
begin
  SetLength(_Bitmap, 0, 0); // Required to reset the bitmap
  SetLength(_Bitmap, Width, height);
end;

procedure TBunker.Update;
begin
  Paint;
end;

end.