unit Utilities;

interface

uses Types, MMSystem, SysUtils, JclFileUtils, Math;

type
  TUtility = class
  public
    class procedure PlayWave(SoundName : String; Looping : Boolean = false);

    class function SpriteCenter(SourceWidth : Integer; DestWidth : Integer; Offset : Integer) : Integer;
    class function SpriteTopAlign(SrcHeight : Integer; DestHeight : Integer; Offset : Integer): Integer;
    class function SpriteMiddleAlign(SrcHeight : Integer; DestHeight : Integer; Offset : Integer) : Integer;
    class function SpriteBottomAlign(SrcHeight : Integer; DestHeight : Integer; Offset : Integer) : Integer;

    class function PtInRect(Rect : TRect; Point : TPoint) : Boolean;
    class function PointInRect(const Rect: TRect; const P: TPoint): Boolean;
    class function Overlaps(U, R: TRect): boolean;
  end;

implementation

{ TUtility }

class procedure TUtility.PlayWave(SoundName: String; Looping: Boolean);
var
  Filename : String;
begin
  // SND_SYNC specifies that the sound is played synchronously and the function does not return until the sound ends.
  // SND_ASYNC specifies that the sound is played asynchronously and the function returns immediately after beginning the sound.
  // SND_NODEFAULT specifies that if the sound cannot be found, the function returns silently without playing the default sound.
  // SND_LOOP specifies that the sound will continue to play continuously until sndPlaySound is called again with the lpszSoundName$ parameter set to null. You must also specify the SND_ASYNC flag to loop sounds.
  // SND_NOSTOP specifies that if a sound is currently playing, the function will immediately return False without playing the requested sound.
  try
    Filename := 'sounds'+DirDelimiter+SoundName+'.wav';
    if Looping then begin
      PlaySoundW(PWideChar(Filename), 0, SND_ASYNC or SND_NODEFAULT or SND_LOOP);
    end else begin
      PlaySoundW(PWideChar(Filename), 0, SND_ASYNC or SND_NODEFAULT);
    end;
  except
    Beep;
  end;
end;

class function TUtility.SpriteBottomAlign(SrcHeight, DestHeight,
  Offset: Integer): Integer;
begin
  result := Offset + (SrcHeight - DestHeight);
end;

class function TUtility.SpriteTopAlign(SrcHeight, DestHeight,
  Offset: Integer): Integer;
begin
  result := Offset - (SrcHeight - DestHeight);
end;

class function TUtility.SpriteCenter(SourceWidth, DestWidth,
  Offset: Integer): Integer;
begin
  result := Offset + (SourceWidth - DestWidth) div 2;
end;

class function TUtility.SpriteMiddleAlign(SrcHeight, DestHeight,
  Offset: Integer): Integer;
begin
  result := Offset + (SrcHeight - DestHeight) div 2;
end;

class function TUtility.PtInRect(Rect : TRect; Point : TPoint) : Boolean;
begin
  // Rectangle normalization
  Rect.Top := Min(Rect.Top, Rect.Bottom);
  Rect.Bottom := Max(Rect.Top, Rect.Bottom);
  Rect.Left := Min(Rect.Left, Rect.Right);
  Rect.Right := Max(Rect.Left, Rect.Right);

  result := ((Point.X>= Rect.Left) and (Point.X<= Rect.Right)) and
  ((Point.Y>= Rect.Top) and (Point.Y<= Rect.Bottom));
end;

class function TUtility.PointInRect(const Rect: TRect; const P: TPoint): Boolean;
begin
  Result := (P.X >= Rect.Left) and (P.X <= Rect.Right) and (P.Y >= Rect.Top)
    and (P.Y <= Rect.Bottom);
end;

class function TUtility.Overlaps(U, R: TRect): boolean;
begin
  result :=
  PointInRect(R, Point(U.Left, U.Top)) or
  PointInRect(R, Point(U.Right, U.Top)) or
  PointInRect(R, Point(U.Left, U.Bottom)) or
  PointInRect(R, Point(U.Right, U.Bottom));

  if not(result) then begin
    result :=
      PointInRect(U, Point(R.Left, R.Top)) or
      PointInRect(U, Point(R.Right, R.Top)) or
      PointInRect(U, Point(R.Left, R.Bottom)) or
      PointInRect(U, Point(R.Right, R.Bottom));
  end;
end;

end.
