program dcmTest;

{$APPTYPE CONSOLE}

///// LUX.DICOM の単体テスト（コンソール）
///// ・失敗があれば NG 行を表示し、終了コード 1 を返す。

uses System.SysUtils,
     LUX.DICOM.core   in '..\..\Core\LUX.DICOM.core.pas'  ,
     LUX.DICOM.VRs    in '..\..\Core\LUX.DICOM.VRs.pas'   ,
     LUX.DICOM.Syntax in '..\..\Core\LUX.DICOM.Syntax.pas';

var
   _PassN :Integer = 0;
   _FailN :Integer = 0;

procedure Check( const OK_:Boolean; const Name_:String );
begin
     if OK_ then Inc( _PassN )
     else
     begin
          Inc( _FailN );  Writeln( 'NG: ', Name_ );
     end;
end;

//------------------------------------------------------------------------------

procedure TestTag;
var
   A, B :TdcmTag;
begin
     A := TdcmTag.Create( $0008, $0018 );
     B := TdcmTag.Create( $7FE0, $0010 );

     Check( A.ToString = '(0008,0018)'          , 'TdcmTag.ToString'                );
     Check( A.Key = $00080018                   , 'TdcmTag.Key'                     );
     Check( A < B                               , 'TdcmTag 順序（Grup 優先）'        );
     Check( TdcmTag.Create( $0008, $FFFF )
          < TdcmTag.Create( $0009, $0000 )      , 'TdcmTag 順序（Elem 繰り上がり）'  );
     Check( A = TdcmTag.Create( $0008, $0018 )  , 'TdcmTag 等値'                    );
     Check( A <> B                              , 'TdcmTag 非等値'                  );
     Check( not A.IsPrivate                     , 'TdcmTag.IsPrivate（偶数）'        );
     Check( TdcmTag.Create( $0009, $0001 ).IsPrivate, 'TdcmTag.IsPrivate（奇数）'    );
     Check( TdcmTag.Create( $FFFE, $E000 ).IsDelimit, 'TdcmTag.IsDelimit'           );
     Check( TdcmTag.Create( $0008, $0000 ).IsGroupLen, 'TdcmTag.IsGroupLen'         );
end;

//------------------------------------------------------------------------------

procedure TestVR;
var
   K :TdcmVRKind;
   N :String;
begin
     ///// 全 VR 名の往復（名前 → 列挙値 → 名前）

     for K := Succ( Low( TdcmVRKind ) ) to High( TdcmVRKind ) do
     begin
          N := VRName( K );

          Check( VRKindOf( AnsiChar( N[1] ), AnsiChar( N[2] ) ) = K, 'VR 往復: ' + N );
     end;

     Check( VRKindOf( 'Z', 'Z' ) = vrNone, '未知 VR 名 → vrNone'  );
     Check( VRKindOf( #0 , #0  ) = vrNone, 'NUL VR 名 → vrNone'   );

     ///// 性質表の抜き取り検査

     Check(     _VRInfo_[ vrOB ].IsLong, 'OB は long 形式'  );
     Check(     _VRInfo_[ vrUV ].IsLong, 'UV は long 形式'  );
     Check( not _VRInfo_[ vrUS ].IsLong, 'US は short 形式' );
     Check( _VRInfo_[ vrUI ].Pad  = $00, 'UI のパディングは NUL' );
     Check( _VRInfo_[ vrPN ].Pad  = $20, 'PN のパディングは空白' );
     Check( _VRInfo_[ vrOW ].Swap = 2  , 'OW の交換単位は 2'     );
     Check( _VRInfo_[ vrFD ].Swap = 8  , 'FD の交換単位は 8'     );
     Check( _VRInfo_[ vrPN ].IsTxt     , 'PN は文字集合の影響を受ける' );
     Check( not _VRInfo_[ vrUI ].IsTxt , 'UI は文字集合の影響を受けない' );
     Check( not _VRInfo_[ vrLT ].HasVM , 'LT は多値を持たない'   );
end;

//------------------------------------------------------------------------------

procedure TestSyntax;
var
   S :TdcmTranSyn;
begin
     S := TdcmTranSyn.From( UID_ImplicitVRLittleEndian );
     Check( ( not S.IsExplic ) and ( not S.IsEncaps ) and S.IsKnown, 'Implicit VR LE' );

     S := TdcmTranSyn.From( UID_ExplicitVRLittleEndian + #0 );   // 末尾 NUL 除去も検査
     Check( S.IsExplic and ( not S.IsBigEnd ) and ( not S.IsEncaps ) and ( S.UID = UID_ExplicitVRLittleEndian ), 'Explicit VR LE（NUL 除去）' );

     S := TdcmTranSyn.From( UID_DeflatedExplicitVRLittleEndian );
     Check( S.IsDeflate and ( not S.IsEncaps ), 'Deflated Explicit VR LE' );

     S := TdcmTranSyn.From( UID_ExplicitVRBigEndian );
     Check( S.IsBigEnd and S.IsExplic, 'Explicit VR BE' );

     S := TdcmTranSyn.From( UID_JPEGLosslessSV1 );
     Check( S.IsEncaps and S.IsExplic and S.IsKnown, 'JPEG Lossless SV1 はカプセル化' );

     S := TdcmTranSyn.From( '1.2.840.10008.1.2.4.999' );   // 未知 UID
     Check( S.IsEncaps and S.IsExplic and ( not S.IsKnown ), '未知 UID → Explicit LE カプセル化と推定' );
end;

//------------------------------------------------------------------------------

begin
     try
          TestTag;
          TestVR;
          TestSyntax;

          Writeln( Format( 'PASS: %d / FAIL: %d', [ _PassN, _FailN ] ) );

          if _FailN > 0 then ExitCode := 1;
     except
          on X:Exception do
          begin
               Writeln( X.ClassName, ': ', X.Message );  ExitCode := 2;
          end;
     end;
end.
