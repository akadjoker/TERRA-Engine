{***********************************************************************************************************************
 *
 * TERRA Game Engine
 * ==========================================
 *
 * Copyright (C) 2003, 2014 by S�rgio Flores (relfos@gmail.com)
 *
 ***********************************************************************************************************************
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
 * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 **********************************************************************************************************************
 * TERRA_Lights
 * Implements the various light classes
 ***********************************************************************************************************************
}

Unit TERRA_Lights;

{-$DEFINE DRAWVOLUMES}

{$I terra.inc}
Interface
Uses {$IFDEF USEDEBUGUNIT}TERRA_Debug,{$ENDIF}
  TERRA_Shader, {$IFDEF DEBUG_GL}TERRA_DebugGL{$ELSE}TERRA_GL{$ENDIF}, TERRA_Utils, TERRA_Math, TERRA_Texture, TERRA_Matrix4x4,
  TERRA_Vector3D, TERRA_Color, TERRA_Application, TERRA_BoundingBox;

Const
  {$IFDEF MOBILE}
  MaxLightsPerMesh = 3;
  {$ELSE}
  MaxLightsPerMesh = 5;
  {$ENDIF}

  lightTypeDirectional  = 0;
  lightTypePoint        = 1;
  lightTypeSpot         = 2;

Type
  Light = Class(TERRAObject)
    Protected
      _Color:Color;
      _Distance:Single;
      _Static:Boolean;
      _Priority:Integer;

      _Next:Light;
      _Frame:Integer;

      Procedure SetupUniforms(Index:Integer; Var TextureSlot:Integer); Virtual; Abstract;

      Procedure UpdateDistance(Target:Vector3D); Virtual;

    Public
      Intensity:Single;
      Enabled:Boolean;

      Procedure Release; Override;

      Function GetPosition():Vector3D; Virtual; Abstract;
      Function IsOccluded():Boolean; Virtual; Abstract;

      {$IFDEF DRAWVOLUMES}
      Procedure Render; Virtual;
      {$ENDIF}

      Property Color:TERRA_Color.Color Read _Color Write _Color;
      Property Static:Boolean Read _Static Write _Static;
      Property Priority:Integer Read _Priority Write _Priority;
  End;

  DirectionalLight = Class(Light)
    Protected
      _Direction:Vector3D;

      Procedure SetupUniforms(Index:Integer; Var TextureSlot:Integer); Override;

    Public
      Constructor Create(Dir:Vector3D);

      Procedure SetDirection(Dir:Vector3D);

      Function IsOccluded():Boolean; Override;

      Function GetPosition():Vector3D; Override;

      Property Direction:Vector3D Read _Direction Write SetDirection;
  End;

  PositionalLight = Class(Light)
    Protected
      _Position:Vector3D;

    Public
      Procedure SetPosition(Pos:Vector3D); Virtual;

      Property Position:Vector3D Read _Position Write SetPosition;
  End;

  PointLight = Class(PositionalLight)
    Protected
      _Radius:Single;

      Procedure SetupUniforms(Index:Integer; Var TextureSlot:Integer); Override;

      Procedure UpdateDistance(Target:Vector3D); Override;

    Public
      Constructor Create(P:Vector3D);

      Procedure SetRadius(R:Single);

      Function GetPosition():Vector3D; Override;
      Function IsOccluded():Boolean; Override;

      Property Radius:Single Read _Radius Write _Radius;
  End;

  SpotLight = Class(PositionalLight)
    Protected
      _Direction:Vector3D;
      _OuterAngle:Single;
      _InnerAngle:Single;
      _ProjectionMatrix4x4:Matrix4x4;
      {$IFDEF DRAWVOLUMES}
      _Instance:Pointer;
      _Alpha:Single;
      {$ENDIF}

      Procedure UpdateMatrix4x4();
      Procedure SetupUniforms(Index:Integer; Var TextureSlot:Integer); Override;

      Procedure UpdateDistance(Target:Vector3D); Override;

    Public
      Cookie:Texture;

      Constructor Create(P, Dir:Vector3D; InnerAngle, OuterAngle:Single);

      Procedure SetDirection(Dir:Vector3D);
      Procedure SetPosition(Pos:Vector3D); Override;

      Function GetPosition():Vector3D; Override;
      Function IsOccluded():Boolean; Override;

      {$IFDEF DRAWVOLUMES}
      Procedure SetAlpha(A:Single);
      Procedure Render; Override;
      {$ENDIF}


      Property InnerAngle:Single Read _InnerAngle Write _InnerAngle;
      Property OuterAngle:Single Read _OuterAngle Write _OuterAngle;
      Property Direction:Vector3D Read _Direction Write SetDirection;
  End;

  PLightBatch = ^LightBatch;
  LightBatch = Record
    DirectionalLights:Array[0..Pred(MaxLightsPerMesh)] Of DirectionalLight;
    DirectionalLightCount:Integer;

    PointLights:Array[0..Pred(MaxLightsPerMesh)] Of PointLight;
    PointLightCount:Integer;

    SpotLights:Array[0..Pred(MaxLightsPerMesh)] Of SpotLight;
    SpotLightCount:Integer;
  End;

  LightManager = Class(ApplicationComponent)
    Protected
      _FirstLight:Light;
      _CurrentFrame:Integer;
      _LightCount:Integer;
      
      _AmbientColor:Color;


      Procedure SetAmbientColor(Value:Color);

    Public
      Procedure Init; Override;

      Procedure Release; Override;

      Procedure Clear;

      Procedure AddLight(Source:Light);

      Function SortLights(Target:Vector3D; Box:BoundingBox):LightBatch;
      Procedure SetupUniforms(Batch:PLightBatch; Var TextureSlot:Integer);

      Function GetDefaultDirection():Vector3D;

      Property LightCount:Integer Read _LightCount;

      Property AmbientColor:Color Read _AmbientColor Write SetAmbientColor;

      Class Function Instance:LightManager;
  End;

Implementation
Uses TERRA_GraphicsManager, TERRA_Mesh
  {$IFDEF DRAWVOLUMES},TERRA_Solids{$ENDIF};

Var
  _LightManager_Instance:ApplicationObject = Nil;

{ Light }
Procedure Light.Release;
Begin
  // do nothing
End;

{$IFDEF DRAWVOLUMES}
Procedure Light.Render;
Begin
  // do nothing
End;
{$ENDIF}

{ LightManager }
Class Function LightManager.Instance:LightManager;
Begin
  If Not Assigned(_LightManager_Instance) Then
    _LightManager_Instance := InitializeApplicationComponent(LightManager, GraphicsManager);

  Result := LightManager(_LightManager_Instance.Instance);
End;

Procedure LightManager.Init;
Begin
  AmbientColor := ColorGrey(32);
  _LightCount := 0;
  //VectorCreate(0.25, 0.75, 0.0);
End;

Procedure LightManager.Release;
Begin
  Clear;
  _LightManager_Instance := Nil;
End;

Procedure LightManager.Clear;
Begin
  _FirstLight := Nil;
  _LightCount := 0;
  Inc(_CurrentFrame);
End;

Procedure LightManager.AddLight(Source:Light);
Begin
  If (Source=Nil) Or (Source._Frame = Self._CurrentFrame) Or (Source.Intensity<=0.0) Then
    Exit;

  If (Not GraphicsManager.Instance.Settings.DynamicLights.Enabled) Then
    Exit;

  Source._Frame := Self._CurrentFrame;

  If (Source.IsOccluded()) Then
    Exit;

  {$IFDEF DRAWVOLUMES}
  Source.Render();
  {$ENDIF}

  Source._Next := _FirstLight;
  _FirstLight := Source;
  Inc(_LightCount);
End;

Function LightManager.SortLights(Target:Vector3D; Box:BoundingBox):LightBatch;
Var
  I, J, K:Integer;
  P:Vector3D;
  MyLight:Light;
  Lights:Array[0..Pred(MaxLightsPerMesh)] Of Light;
  LightCount:Integer;
Begin
  Result.DirectionalLightCount := 0;
  Result.PointLightCount := 0;
  Result.SpotLightCount := 0;

  If (Not GraphicsManager.Instance.Settings.DynamicLights.Enabled) Then
    Exit;

  For I:=0 To Pred(MaxLightsPerMesh) Do
  Begin
    Result.DirectionalLights[I] := Nil;
    Result.PointLights[I] := Nil;
    Result.SpotLights[I] := Nil;
    Lights[I] := Nil;
  End;

  LightCount := 0;

  MyLight := _FirstLight;
  While Assigned(MyLight) Do
  Begin
    If (_LightCount<MaxLightsPerMesh) Then
    Begin
      Lights[LightCount] := MyLight;
      Inc(LightCount);

      MyLight := MyLight._Next;
      Continue;
    End;

    If (MyLight Is DirectionalLight) And (LightCount<MaxLightsPerMesh) Then
    Begin
      MyLight._Distance := 0;

      Lights[LightCount] := DirectionalLight(MyLight);
      Inc(LightCount);

      MyLight := MyLight._Next;
      Continue;
    End;

    P := MyLight.GetPosition();
    MyLight.UpdateDistance(Target);

    If (MyLight Is PositionalLight) Then
    Begin
      For J:=0 To Pred(MaxLightsPerMesh) Do
      If (Lights[J] = Nil) Then
      Begin
        Lights[J] := MyLight;
        Inc(LightCount);
        Break;
      End Else
      If (MyLight._Distance<Lights[J]._Distance) Or (MyLight._Priority>Lights[J]._Priority) Then
      Begin
        For K:=Pred(MaxLightsPerMesh) DownTo Succ(J) Do
          Lights[K] := Lights[K-1];

        Lights[J] := MyLight;

        If LightCount<MaxLightsPerMesh Then
          Inc(LightCount);

        Break;
      End;
    End;

    MyLight := MyLight._Next;
  End;

  For I:=0 To Pred(LightCount) Do
  If (Lights[I] = Nil) Then
    Break
  Else
  If (Lights[I] Is PointLight) Then
  Begin
    Result.PointLights[Result.PointLightCount] := PointLight(Lights[I]);
    Inc(Result.PointLightCount);
  End Else
  If (Lights[I] Is DirectionalLight) Then
  Begin
    Result.DirectionalLights[Result.DirectionalLightCount] := DirectionalLight(Lights[I]);
    Inc(Result.DirectionalLightCount);
  End Else
  If (Lights[I] Is SpotLight) Then
  Begin
    Result.SpotLights[Result.SpotLightCount] := SpotLight(Lights[I]);
    Inc(Result.SpotLightCount);
  End;
End;

Procedure LightManager.SetAmbientColor(Value: Color);
Begin
  _AmbientColor := Value;
End;

{ PositionalLight }
Procedure PositionalLight.SetPosition(Pos: Vector3D);
Begin
  _Position := Pos;
End;

{ PointLight }
Constructor PointLight.Create(P:Vector3D);
Begin
  SetPosition(P);
  Self._Color := ColorWhite;
  Self.Intensity := 1.0;
  Self.Enabled := True;
End;

Function PointLight.GetPosition: Vector3D;
Begin
  Result := Self._Position;
End;

Procedure PointLight.SetupUniforms(Index:Integer; Var TextureSlot:Integer);
Var
  _Shader:Shader;
Begin
  _Shader := ShaderManager.Instance.ActiveShader;
  If _Shader = Nil Then
    Exit;

  _Shader.SetUniform('plightPosition'+IntToString(Index), _Position);
  _Shader.SetUniform('plightRadius'+IntToString(Index), 1/_Radius);
  _Shader.SetUniform('plightColor'+IntToString(Index), ColorScale(_Color, Intensity));
End;

Function PointLight.IsOccluded: Boolean;
Var
  Sphere:BoundingSphere;
Begin
  Sphere.Center := _Position;
  Sphere.Radius := _Radius;
  Result := Not GraphicsManager.Instance.ActiveViewport.Camera.Frustum.SphereVisible(Sphere);
End;

Procedure PointLight.SetRadius(R: Single);
Begin
  _Radius := R;
End;

Procedure PointLight.UpdateDistance(Target: Vector3D);
Var
  N:Vector3D;
Begin
  N := VectorSubtract(Target, _Position);
  N.Normalize();

  N := VectorAdd(_Position, VectorScale(N, Self._Radius));

  _Distance := N.Distance(Target);
End;

{ DirectionalLight }
Constructor DirectionalLight.Create(Dir: Vector3D);
Begin
  Self._Color := ColorWhite;
  Self.Enabled := True;
  Self.Intensity := 1.0;
  SetDirection(Dir);
End;

Function DirectionalLight.GetPosition: Vector3D;
Begin
  Result := Self.Direction;
  Result.Scale(1000);
  Result.Add(GraphicsManager.Instance.ActiveViewport.Camera.Position);
End;

Function DirectionalLight.IsOccluded: Boolean;
Begin
  Result := False;
End;

Procedure DirectionalLight.SetDirection(Dir: Vector3D);
Begin
  _Direction := Dir;
End;

Procedure DirectionalLight.SetupUniforms(Index: Integer; Var TextureSlot:Integer);
Var
  _Shader:Shader;
Begin
  _Shader := ShaderManager.Instance.ActiveShader;
  If _Shader = Nil Then
    Exit;

  _Shader.SetUniform('dlightDirection'+IntToString(Index), _Direction);
  _Shader.SetUniform('dlightColor'+IntToString(Index), ColorScale(_Color, Intensity));
End;

Procedure LightManager.SetupUniforms(Batch: PLightBatch; Var TextureSlot:Integer);
Var
  I:Integer;
  _Shader:Shader;
Begin
  _Shader := ShaderManager.Instance.ActiveShader;

  For I:=0 To Pred(Batch.DirectionalLightCount) Do
    Batch.DirectionalLights[I].SetupUniforms(Succ(I), TextureSlot);

  For I:=0 To Pred(Batch.PointLightCount) Do
    Batch.PointLights[I].SetupUniforms(Succ(I), TextureSlot);

  For I:=0 To Pred(Batch.SpotLightCount) Do
    Batch.SpotLights[I].SetupUniforms(Succ(I), TextureSlot);
End;

Function LightManager.GetDefaultDirection: Vector3D;
Var
  MyLight:Light;
Begin
  Result := VectorCreate(-0.25, 0.75, 0.0);

  MyLight := _FirstLight;
  While Assigned(MyLight) Do
  If (MyLight Is DirectionalLight) Then
  Begin
    Result := DirectionalLight(MyLight)._Direction;
    Exit;
  End Else
    MyLight := MyLight._Next;
End;

Var
  _ConeMesh:Mesh;

{ SpotLight }
Constructor SpotLight.Create(P, Dir:Vector3D; InnerAngle, OuterAngle:Single);
{$IFDEF DRAWVOLUMES}
Var
  S:SolidMesh;
  Inst:MeshInstance;
{$ENDIF}
Begin
{$IFDEF DRAWVOLUMES}
  If (_ConeMesh=Nil) Then
  Begin
    S := ConeMesh.Create(1, 8);
    _ConeMesh := CreateMeshFromSolid(S);
    S.Release;
  End;

  Inst := MeshInstance.Create(_ConeMesh);
  Self._Instance := Inst;
  Self._Alpha := 0.0;
{$ENDIF}

  Self.Enabled := True;
  Self._Color := ColorWhite;
  Self._InnerAngle := InnerAngle;
  Self._OuterAngle := OuterAngle;
  Self.Intensity := 1.0;
  Self.Cookie := TextureManager.Instance.WhiteTexture;
  SetDirection(Dir);
  SetPosition(P);
End;

Function SpotLight.GetPosition: Vector3D;
Begin
  Result := _Position;
End;

Function SpotLight.IsOccluded: Boolean;
Begin
  Result := False;
End;

{$IFDEF DRAWVOLUMES}
Procedure SpotLight.Render;
Var
  A:Byte;
  Inst:MeshInstance;
Begin
  If (_Alpha<=0.0) Then
    Exit;

  Inst := MeshInstance(_Instance);
  If (Inst = Nil) Then
    Exit;

  A := Trunc(255*_Alpha);
  Inst.SetColor(0, ColorCreate(_Color.R, _Color.G, _Color.B, A));
  GraphicsManager.Instance.AddRenderable(Inst);
End;

Procedure SpotLight.SetAlpha(A: Single);
Begin
  _Alpha := A;
  UpdateMatrix4x4();
End;
{$ENDIF}

Procedure SpotLight.SetDirection(Dir: Vector3D);
Begin
  _Direction := Dir;
  UpdateMatrix4x4();
End;

Procedure SpotLight.SetPosition(Pos: Vector3D);
Begin
  _Position := Pos;
  UpdateMatrix4x4();
End;

Procedure SpotLight.SetupUniforms(Index: Integer; Var TextureSlot:Integer);
Var
  _Shader:Shader;
Begin
  _Shader := ShaderManager.Instance.ActiveShader;
  If _Shader = Nil Then
    Exit;

  _Shader.SetUniform('slightPosition'+IntToString(Index), _Position);
  _Shader.SetUniform('slightDirection'+IntToString(Index), _Direction);
  _Shader.SetUniform('slightCosInnerAngle'+IntToString(Index), Cos(_InnerAngle));
  _Shader.SetUniform('slightCosOuterAngle'+IntToString(Index), Cos(_OuterAngle));
  _Shader.SetUniform('slightColor'+IntToString(Index), _Color);
  _Shader.SetUniform('slightMatrix'+IntToString(Index), _ProjectionMatrix4x4);
  _Shader.SetUniform('slightCookie'+IntToString(Index), TextureSlot);

  If Assigned(Cookie) Then
  Begin
    Cookie.Bind(TextureSlot);
    Inc(TextureSlot);
  End;
End;

Procedure SpotLight.UpdateDistance(Target: Vector3D);
{Var
  N:Vector3D;}
Begin
{  N := VectorSubtract(Target, _Position);
  N.Normalize();

  N := VectorAdd(_Position, VectorScale(N, Self._Radius));}

  _Distance := _Position.Distance(Target);
End;

Procedure SpotLight.UpdateMatrix4x4;
Var
  Roll:Vector3D;
  M, M2:Matrix4x4;
Begin
  If (Abs(_Direction.Y)>=0.999) Then
    Roll := VectorCreate(0, 0, 1)
  Else
    Roll := VectorUp;

  M := Matrix4x4LookAt(_Position, VectorAdd(_Position, VectorScale(_Direction, 50)), Roll);
  M2 := Matrix4x4Perspective(DEG*_OuterAngle, 1.0, 0.1, 1000);
  _ProjectionMatrix4x4 := Matrix4x4Multiply4x4(M2, M);

  {$IFDEF DRAWVOLUMES}
  Inst := _Instance;
  If Assigned(Inst) Then
  Begin
    Len := 100;
    S := Tan(_OuterAngle) * Len;
    If (Abs(_Direction.Y)>=0.999) Then
      M := Matrix4x4Transform(_Position, VectorCreate(0.0, 0.0, -_Direction.Y*180*RAD), VectorCreate(S, Len, S))
    Else
      M := Matrix4x4Orientation(_Position, _Direction, VectorCreate(0, 1.0, 0.0), VectorCreate(S, Len, S));
    Inst.SetTransform(M);
  End;
  {$ENDIF}
End;

Procedure Light.UpdateDistance;
Begin
  _Distance := 0;
End;


End.
