#ifndef LIGHTWEIGHT_SHADOWS_INCLUDED
#define LIGHTWEIGHT_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Core.hlsl"

#define MAX_SHADOW_CASCADES 4

#ifndef SHADOWS_SCREEN
#if defined(_MAIN_LIGHT_SHADOWS) && defined(_MAIN_LIGHT_SHADOWS_CASCADE) && !defined(SHADER_API_GLES)
#define SHADOWS_SCREEN 1
#else
#define SHADOWS_SCREEN 0
#endif
#endif

SCREENSPACE_TEXTURE(_ScreenSpaceShadowmapTexture);
SAMPLER(sampler_ScreenSpaceShadowmapTexture);

TEXTURE2D_SHADOW(_MainLightShadowmapTexture);
SAMPLER_CMP(sampler_MainLightShadowmapTexture);

TEXTURE2D_SHADOW(_MainCharacterShadowmapTexture);
SAMPLER_CMP(sampler_MainCharacterShadowmapTexture);

TEXTURE2D_SHADOW(_AdditionalLightsShadowmapTexture);
SAMPLER_CMP(sampler_AdditionalLightsShadowmapTexture);

TEXTURE2D(_DeepShadowLut);
SAMPLER(sampler_DeepShadowLut);

CBUFFER_START(_MainLightShadowBuffer)
// Last cascade is initialized with a no-op matrix. It always transforms
// shadow coord to half3(0, 0, NEAR_PLANE). We use this trick to avoid
// branching since ComputeCascadeIndex can return cascade index = MAX_SHADOW_CASCADES
float4x4    _MainLightWorldToShadow[MAX_SHADOW_CASCADES + 1];
float4      _CascadeShadowSplitSpheres0;
float4      _CascadeShadowSplitSpheres1;
float4      _CascadeShadowSplitSpheres2;
float4      _CascadeShadowSplitSpheres3;
float4      _CascadeShadowSplitSphereRadii;
half4       _MainLightShadowOffset0;
half4       _MainLightShadowOffset1;
half4       _MainLightShadowOffset2;
half4       _MainLightShadowOffset3;
half4       _MainLightShadowData;    // (x: shadowStrength)
float4      _MainLightShadowmapSize; // (xy: 1/width and 1/height, zw: width and height)
CBUFFER_END

CBUFFER_START(_AdditionalLightsShadowBuffer)
float4x4    _AdditionalLightsWorldToShadow[MAX_VISIBLE_LIGHTS];
half        _AdditionalShadowStrength[MAX_VISIBLE_LIGHTS];
half4       _AdditionalShadowOffset0;
half4       _AdditionalShadowOffset1;
half4       _AdditionalShadowOffset2;
half4       _AdditionalShadowOffset3;
float4      _AdditionalShadowmapSize; // (xy: 1/width and 1/height, zw: width and height)
CBUFFER_END

CBUFFER_START(_MainCharacterShadowBuffer)
float4x4 _MainCharacterWorldToShadow;
half _MainCharacterShadowStrength;
float4 _MainCharacterShadowmapSize;
half4       _MainCharacterShadowOffset0;
half4       _MainCharacterShadowOffset1;
half4       _MainCharacterShadowOffset2;
half4       _MainCharacterShadowOffset3;
float4		_MainCharacterCullingSphere;
CBUFFER_END

CBUFFER_START(_DeepShadowMapsBuffer)
float4x4 _DeepShadowMapsWorldToShadow;
half _DeepShadowStrength;
float4 _DeepShadowMapsCullingSphere;
uint _DeepShadowMapSize;
uint _DeepShadowMapDepth;
CBUFFER_END

#if UNITY_REVERSED_Z
#define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= UNITY_RAW_FAR_CLIP_VALUE
#else
#define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z >= UNITY_RAW_FAR_CLIP_VALUE
#endif

struct ShadowSamplingData
{
    half4 shadowOffset0;
    half4 shadowOffset1;
    half4 shadowOffset2;
    half4 shadowOffset3;
    float4 shadowmapSize;
};

ShadowSamplingData GetMainLightShadowSamplingData()
{
    ShadowSamplingData shadowSamplingData;
    shadowSamplingData.shadowOffset0 = _MainLightShadowOffset0;
    shadowSamplingData.shadowOffset1 = _MainLightShadowOffset1;
    shadowSamplingData.shadowOffset2 = _MainLightShadowOffset2;
    shadowSamplingData.shadowOffset3 = _MainLightShadowOffset3;
    shadowSamplingData.shadowmapSize = _MainLightShadowmapSize;
    return shadowSamplingData;
}

ShadowSamplingData GetMainCharacterShadowSamplingData()
{
	ShadowSamplingData shadowSamplingData;
	shadowSamplingData.shadowOffset0 = _MainCharacterShadowOffset0;
	shadowSamplingData.shadowOffset1 = _MainCharacterShadowOffset1;
	shadowSamplingData.shadowOffset2 = _MainCharacterShadowOffset2;
	shadowSamplingData.shadowOffset3 = _MainCharacterShadowOffset3;
	shadowSamplingData.shadowmapSize = _MainCharacterShadowmapSize;
	return shadowSamplingData;
}

ShadowSamplingData GetAdditionalLightShadowSamplingData()
{
    ShadowSamplingData shadowSamplingData;
    shadowSamplingData.shadowOffset0 = _AdditionalShadowOffset0;
    shadowSamplingData.shadowOffset1 = _AdditionalShadowOffset1;
    shadowSamplingData.shadowOffset2 = _AdditionalShadowOffset2;
    shadowSamplingData.shadowOffset3 = _AdditionalShadowOffset3;
    shadowSamplingData.shadowmapSize = _AdditionalShadowmapSize;
    return shadowSamplingData;
}

half GetMainLightShadowStrength()
{
    return _MainLightShadowData.x;
}

half GetAdditionalLightShadowStrenth(int lightIndex)
{
    return _AdditionalShadowStrength[lightIndex];
}

half SampleScreenSpaceShadowmap(float4 shadowCoord)
{
    shadowCoord.xy /= shadowCoord.w;

    // The stereo transform has to happen after the manual perspective divide
    shadowCoord.xy = UnityStereoTransformScreenSpaceTex(shadowCoord.xy);

#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    half attenuation = SAMPLE_TEXTURE2D_ARRAY(_ScreenSpaceShadowmapTexture, sampler_ScreenSpaceShadowmapTexture, shadowCoord.xy, unity_StereoEyeIndex).x;
#else
    half attenuation = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_ScreenSpaceShadowmapTexture, shadowCoord.xy).x;
#endif

    return attenuation;
}

real SampleShadowmap(float4 shadowCoord, TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), ShadowSamplingData samplingData, half shadowStrength, bool isPerspectiveProjection = true)
{
    // Compiler will optimize this branch away as long as isPerspectiveProjection is known at compile time
    if (isPerspectiveProjection)
        shadowCoord.xyz /= shadowCoord.w;

    real attenuation;

#ifdef _SHADOWS_SOFT
    #ifdef SHADER_API_MOBILE
        // 4-tap hardware comparison
        real4 attenuation4;
        attenuation4.x = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset0.xyz);
        attenuation4.y = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset1.xyz);
        attenuation4.z = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset2.xyz);
        attenuation4.w = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset3.xyz);
        attenuation = dot(attenuation4, 0.25);
    #else
        float fetchesWeights[9];
        float2 fetchesUV[9];
        SampleShadow_ComputeSamples_Tent_5x5(samplingData.shadowmapSize, shadowCoord.xy, fetchesWeights, fetchesUV);

        attenuation  = fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[0].xy, shadowCoord.z));
        attenuation += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[1].xy, shadowCoord.z));
        attenuation += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[2].xy, shadowCoord.z));
        attenuation += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[3].xy, shadowCoord.z));
        attenuation += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[4].xy, shadowCoord.z));
        attenuation += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[5].xy, shadowCoord.z));
        attenuation += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[6].xy, shadowCoord.z));
        attenuation += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[7].xy, shadowCoord.z));
        attenuation += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[8].xy, shadowCoord.z));
    #endif
#else
    // 1-tap hardware comparison
    attenuation = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz);
#endif

    attenuation = LerpWhiteTo(attenuation, shadowStrength);

    // Shadow coords that fall out of the light frustum volume must always return attenuation 1.0
    return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : attenuation;
}

half ComputeCascadeIndex(float3 positionWS)
{
    float3 fromCenter0 = positionWS - _CascadeShadowSplitSpheres0.xyz;
    float3 fromCenter1 = positionWS - _CascadeShadowSplitSpheres1.xyz;
    float3 fromCenter2 = positionWS - _CascadeShadowSplitSpheres2.xyz;
    float3 fromCenter3 = positionWS - _CascadeShadowSplitSpheres3.xyz;
    float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

    half4 weights = half4(distances2 < _CascadeShadowSplitSphereRadii);
    weights.yzw = saturate(weights.yzw - weights.xyz);

    return 4 - dot(weights, half4(4, 3, 2, 1));
}

float4 TransformWorldToShadowCoord(float3 positionWS)
{
#ifdef _MAIN_LIGHT_SHADOWS_CASCADE
    half cascadeIndex = ComputeCascadeIndex(positionWS);
    return mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));
#else
    return mul(_MainLightWorldToShadow[0], float4(positionWS, 1.0));
#endif
}

half MainLightRealtimeShadow(float4 shadowCoord)
{
#if (!defined(_MAIN_LIGHT_SHADOWS) && !defined(_MAIN_CHARACTER_SHADOWS)) || defined(_RECEIVE_SHADOWS_OFF)
    return 1.0h;
#endif

#if SHADOWS_SCREEN
    return SampleScreenSpaceShadowmap(shadowCoord);
#else
    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half shadowStrength = GetMainLightShadowStrength();
    return SampleShadowmap(shadowCoord, TEXTURE2D_PARAM(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
#endif
}

half MainLightRealtimeShadow(float4 shadowCoord, float4 shadowCoord2, float4 shadowCoord3)
{
#if (!defined(_MAIN_LIGHT_SHADOWS) && !defined(_MAIN_CHARACTER_SHADOWS) && !defined(_DEEP_SHADOW_MAPS)) || defined(_RECEIVE_SHADOWS_OFF)
	return 1.0h;
#endif

#if SHADOWS_SCREEN
	return SampleScreenSpaceShadowmap(shadowCoord);
#else
	ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
	half shadowStrength = GetMainLightShadowStrength();
	half atten = SampleShadowmap(shadowCoord, TEXTURE2D_PARAM(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
#ifdef _MAIN_CHARACTER_SHADOWS
		half mcAtten = SampleShadowmap(shadowCoord2, TEXTURE2D_PARAM(_MainCharacterShadowmapTexture, sampler_MainCharacterShadowmapTexture), GetMainCharacterShadowSamplingData(), _MainCharacterShadowStrength, false);
		atten = lerp(atten, mcAtten, shadowCoord2.w);
#endif
#ifdef _DEEP_SHADOW_MAPS
		half dsmAtten = SAMPLE_TEXTURE2D(_DeepShadowLut, sampler_DeepShadowLut, shadowCoord3.xy).r;
		atten = lerp(atten, dsmAtten, shadowCoord3.w);
#endif
	return atten;
#endif
}

half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS)
{
#if !defined(_ADDITIONAL_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
    return 1.0h;
#else
    float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[lightIndex], float4(positionWS, 1.0));
    ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData();
    half shadowStrength = GetAdditionalLightShadowStrenth(lightIndex);
    return SampleShadowmap(shadowCoord, TEXTURE2D_PARAM(_AdditionalLightsShadowmapTexture, sampler_AdditionalLightsShadowmapTexture), shadowSamplingData, shadowStrength, true);
#endif
}

float4 GetShadowCoord(VertexPositionInputs vertexInput)
{
#if SHADOWS_SCREEN
    return ComputeScreenPos(vertexInput.positionCS);
#else
    return TransformWorldToShadowCoord(vertexInput.positionWS);
#endif
}

float4 TransformWorldToMCShadowCoord(float3 positionWS)
{
	float3 fromCenter = positionWS - _MainCharacterCullingSphere.xyz;
	float distances2 = dot(fromCenter, fromCenter);
	half weight = distances2 < _MainCharacterCullingSphere.z;
	return mul(_MainCharacterWorldToShadow, float4(positionWS, 1)) * weight;
}

#if !SHADOWS_SCREEN
float4 GetShadowCoordMC(VertexPositionInputs vertexInput)
{
	return TransformWorldToMCShadowCoord(vertexInput.positionWS);
}
#endif

half InDeepShadowMaps(float3 positionWS)
{
	float3 fromCenter = positionWS - _DeepShadowMapsCullingSphere.xyz;
	float distances2 = dot(fromCenter, fromCenter);
	half weight = distances2 < _DeepShadowMapsCullingSphere.w;
	return weight;
}

float4 GetScreenSpaceDeepShadowCoord(VertexPositionInputs vertexInput)
{
	float4 screenPos = ComputeScreenPos(vertexInput.positionCS);
	screenPos /= screenPos.w;
	return screenPos * InDeepShadowMaps(vertexInput.positionWS);
}

#endif
