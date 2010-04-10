{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     �й����Լ��Ŀ���Դ�������������                         }
{                   (C)Copyright 2001-2010 CnPack ������                       }
{                   ------------------------------------                       }
{                                                                              }
{            ���������ǿ�Դ���������������������� CnPack �ķ���Э������        }
{        �ĺ����·�����һ����                                                }
{                                                                              }
{            ������һ��������Ŀ����ϣ�������ã���û���κε���������û��        }
{        �ʺ��ض�Ŀ�Ķ������ĵ���������ϸ���������� CnPack ����Э�顣        }
{                                                                              }
{            ��Ӧ���Ѿ��Ϳ�����һ���յ�һ�� CnPack ����Э��ĸ��������        }
{        ��û�У��ɷ������ǵ���վ��                                            }
{                                                                              }
{            ��վ��ַ��http://www.cnpack.org                                   }
{            �����ʼ���master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnFeedParser;
{ |<PRE>
================================================================================
* �������ƣ�CnPack IDE ר�Ұ�
* ��Ԫ���ƣ�RSS Parser ��Ԫ
* ��Ԫ���ߣ��ܾ��� (zjy@cnpack.org)
* ��    ע��
* ����ƽ̨��PWinXP SP3 + Delphi 7.1
* ���ݲ��ԣ�
* �� �� �����õ�Ԫ�е��ַ���֧�ֱ��ػ�������ʽ
* ��Ԫ��ʶ��$Id: $
* �޸ļ�¼��2010.04.08
*               ������Ԫ
================================================================================
|</PRE>}

interface

{$I CnWizards.inc}

uses
  Windows, SysUtils, Classes, CnClasses;

type

  TCnFeedItem = class(TCnAssignableCollectionItem)
  private
    FPubDate: TDateTime;
    FDescription: WideString;
    FCategory: WideString;
    FTitle: WideString;
    FAuthor: WideString;
    FLink: WideString;
  published
    property Title: WideString read FTitle write FTitle;
    property Link: WideString read FLink write FLink;
    property Description: WideString read FDescription write FDescription;
    property Category: WideString read FCategory write FCategory;
    property PubDate: TDateTime read FPubDate write FPubDate;
    property Author: WideString read FAuthor write FAuthor;
  end;

  TCnFeedChannel = class(TCnAssignableCollection)
  private
    FLastBuildDate: TDateTime;
    FPubDate: TDateTime;
    FDescription: WideString;
    FTitle: WideString;
    FLanguage: WideString;
    FLink: WideString;
    FIDStr: WideString;
    function GetItems(Index: Integer): TCnFeedItem;
    procedure SetItems(Index: Integer; const Value: TCnFeedItem);
  public
    constructor Create;
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);

    property Items[Index: Integer]: TCnFeedItem read GetItems write SetItems; default;
  published
    property IDStr: WideString read FIDStr write FIDStr;
    property Title: WideString read FTitle write FTitle;
    property Link: WideString read FLink write FLink;
    property Description: WideString read FDescription write FDescription;
    property Language: WideString read FLanguage write FLanguage;
    property PubDate: TDateTime read FPubDate write FPubDate;
    property LastBuildDate: TDateTime read FLastBuildDate write FLastBuildDate;
  end;

implementation

uses
  OmniXML, OmniXMLUtils;

const
  csShortMonthNames: array[1..12] of string = ('Jan', 'Feb', 'Mar',
    'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

// From: IdGlobal.pas
// www.indyproject.org
function GmtOffsetStrToDateTime(S: string): TDateTime;
begin
  Result := 0.0;
  S := Copy(Trim(s), 1, 5);
  if Length(S) > 0 then
  begin
    if s[1] in ['-', '+'] then
    begin
      try
        Result := EncodeTime(StrToInt(Copy(s, 2, 2)), StrToInt(Copy(s, 4, 2)), 0, 0);
        if s[1] = '-' then
        begin
          Result := -Result;
        end;
      except
        Result := 0.0;
      end;
    end;
  end;
end;

// From: IdGlobal.pas
// www.indyproject.org
function OffsetFromUTC: TDateTime;
var
  iBias: Integer;
  tmez: TTimeZoneInformation;
begin
  Result := 0;
  Case GetTimeZoneInformation(tmez) of
    TIME_ZONE_ID_UNKNOWN  :
      iBias := tmez.Bias;
    TIME_ZONE_ID_DAYLIGHT :
      iBias := tmez.Bias + tmez.DaylightBias;
    TIME_ZONE_ID_STANDARD :
      iBias := tmez.Bias + tmez.StandardBias;
    else
      Exit;
  end;
  {We use ABS because EncodeTime will only accept positve values}
  Result := EncodeTime(Abs(iBias) div 60, Abs(iBias) mod 60, 0, 0);
  {The GetTimeZone function returns values oriented towards convertin
   a GMT time into a local time.  We wish to do the do the opposit by returning
   the difference between the local time and GMT.  So I just make a positive
   value negative and leave a negative value as positive}
  if iBias > 0 then begin
    Result := 0 - Result;
  end;
end;

function FeedStrToDateTime1(S: WideString; var Time: TDateTime): Boolean;
var
  i: Integer;
  T: WideString;
  List: TStringList;
  Y, M, D: Word;
begin
  Result := False;
  try
    // Wed, 09 Sep 2009 12:42:19 GMT
    T := Trim(S);
    if Pos(',', T) = 4 then
    begin
      Delete(T, 1, 4);
      T := Trim(T);
      List := TStringList.Create;
      try
        List.Text := StringReplace(T, ' ', #13#10, [rfReplaceAll]);
        for i := List.Count - 1 downto 0 do
          if Trim(List[i]) = '' then
            List.Delete(i);
        if List.Count > 4 then
        begin
          D := StrToInt(List[0]);
          M := 0;
          for i := Low(csShortMonthNames) to High(csShortMonthNames) do
            if SameText(csShortMonthNames[i], List[1]) then
            begin
              M := i;
              Break;
            end;
          Y := StrToInt(List[2]);
          if Y < 100 then
            Y := 1900 + Y;
          Time := EncodeDate(Y, M, D) + StrToTime(List[3]);
          if List.Count > 4 then
            Time := Time - GmtOffsetStrToDateTime(List[4]);
          Time := Time + OffsetFromUTC;
          Result := True;
        end;
      finally
        List.Free;
      end;
    end;
  except
    ;
  end;
end;

function FeedStrToDateTime2(S: WideString; var Time: TDateTime): Boolean;
var
  T: WideString;
  Y, M, D: Word;
begin
  Result := False;
  try
    T := Trim(S);
    if Length(T) < 19 then Exit;
    // 2010-04-09T14:55:18Z
    if T[11] = 'T' then
    begin
      Y := StrToInt(Copy(T, 1, 4));
      M := StrToInt(Copy(T, 6, 2));
      D := StrToInt(Copy(T, 9, 2));
      Time := EncodeDate(Y, M, D) + StrToTime(Copy(T, 12, 8));
      if (Length(T) > 19) and (T[20] = 'Z') then
        Time := Time + OffsetFromUTC;
      Result := True;
    end;
  except
    ;
  end;
end;  

function FeedStrToDateTime(S: WideString): TDateTime;
begin
  if not FeedStrToDateTime1(S, Result) and not FeedStrToDateTime2(S, Result) then
    Result := Now;
end;

{ TCnFeedChannel }

constructor TCnFeedChannel.Create;
begin
  inherited Create(TCnFeedItem);
end;

function TCnFeedChannel.GetItems(Index: Integer): TCnFeedItem;
begin
  Result := TCnFeedItem(inherited Items[Index]);
end;

procedure TCnFeedChannel.LoadFromFile(const FileName: string);
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    Stream.LoadFromFile(FileName);
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TCnFeedChannel.LoadFromStream(Stream: TStream);
var
  XML: IXMLDocument;
  Node, Item: IXMLNode;
  i: Integer;
begin
  try
    Clear;
    XML := CreateXMLDoc;
    if XML.LoadFromStream(Stream) then
    begin
      // RSS 2.0
      Node := FindNode(XML, 'rss');
      if Node <> nil then
      begin
        Node := FindNode(Node, 'channel');
        if Node <> nil then
        begin
          Title := GetNodeTextStr(Node, 'title', '');
          Link := GetNodeTextStr(Node, 'link', '');
          Description := GetNodeTextStr(Node, 'description', '');
          Language := GetNodeTextStr(Node, 'language', '');
          PubDate := FeedStrToDateTime(GetNodeTextStr(Node, 'pubDate', ''));
          LastBuildDate := FeedStrToDateTime(GetNodeTextStr(Node, 'lastBuildDate', ''));

          for i := 0 to Node.ChildNodes.Length - 1 do
          begin
            if SameText(Node.ChildNodes.Item[i].NodeName, 'item') then
            begin
              Item := Node.ChildNodes.Item[i];
              with TCnFeedItem(Add) do
              begin
                Title := GetNodeTextStr(Item, 'title', '');
                Link := GetNodeTextStr(Item, 'link', '');
                Description := GetNodeTextStr(Item, 'description', '');
                Category := GetNodeTextStr(Item, 'category', '');
                Author := GetNodeTextStr(Item, 'author', '');
                PubDate := FeedStrToDateTime(GetNodeTextStr(Item, 'pubDate', ''));
              end;
            end;
          end;
          Exit;
        end;
      end;

      // ATOM
      Node := FindNode(XML, 'feed');
      if Node <> nil then
      begin
        // todo: Support ATOM format
      end;  
    end;
  except
    ;
  end;
end;

procedure TCnFeedChannel.SetItems(Index: Integer;
  const Value: TCnFeedItem);
begin
  inherited Items[Index] := Value;
end;

end.