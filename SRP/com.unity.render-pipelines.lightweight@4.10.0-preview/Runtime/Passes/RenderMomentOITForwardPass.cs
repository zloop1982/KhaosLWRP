﻿using System;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.LightweightPipeline
{
    public class RenderMomentOITForwardPass : ScriptableRenderPass
    {
        const string _kRenderOITTag = "Render Moment OIT";
        FilterRenderersSettings _OITFilterSettings;
        RenderTargetHandle _DepthAttachmentHandle { get; set; }
        RenderTargetHandle _ColorAttachmentHandle { get; set; }

        RenderTargetHandle _B0Handle;
        RenderTargetHandle _B1Handle;
        RenderTargetHandle _B2Handle;
        RenderTargetBinding _GMBinding;

        RenderTargetHandle _MOITHandle;
        RenderTargetHandle _GIALHandle;
        RenderTargetBinding _RMBinding;

        RenderTextureDescriptor _Descriptor { get; set; }
        RenderTextureDescriptor _DescriptorFloat { get; set; }
        RenderTextureDescriptor _DescriptorFloat4 { get; set; }

        RendererConfiguration _RendererConfiguration;

        public RenderMomentOITForwardPass()
        {
            RegisterShaderPassName("GenerateMoments");
            _OITFilterSettings = new FilterRenderersSettings(true)
            {
                renderQueueRange = RenderQueueUtils.oit,
            };
        }

        MomentsCount _MomentsCount;

        /// <summary>
        /// Configure the pass before execution
        /// </summary>
        /// <param name="baseDescriptor">Current target descriptor</param>
        /// <param name="colorAttachmentHandle">Color attachment to render into</param>
        /// <param name="depthAttachmentHandle">Depth attachment to render into</param>
        /// <param name="configuration">Specific render configuration</param>
        public void Setup(
            RenderTextureDescriptor baseDescriptor,
            RenderTargetHandle colorAttachmentHandle,
            RenderTargetHandle depthAttachmentHandle,
            RendererConfiguration configuration,
            SampleCount samples,
            int momentsCount)
        {
            this._ColorAttachmentHandle = colorAttachmentHandle;
            this._DepthAttachmentHandle = depthAttachmentHandle;
            _RendererConfiguration = configuration;

            if ((int)samples > 1)
            {
                baseDescriptor.bindMS = false;
                baseDescriptor.msaaSamples = (int)samples;
            }

            baseDescriptor.depthBufferBits = 0;

            _Descriptor = baseDescriptor;

            baseDescriptor.colorFormat = RenderTextureFormat.ARGBFloat;
            _DescriptorFloat4 = baseDescriptor;

            baseDescriptor.colorFormat = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RFloat)
                ? RenderTextureFormat.RFloat
                : RenderTextureFormat.ARGBFloat;
            _DescriptorFloat = baseDescriptor;

            _B0Handle.Init("_B0");
            _B1Handle.Init("_B1");
            _B2Handle.Init("_B2");

            _MomentsCount = (MomentsCount)momentsCount;

            if (MomentsCount._8 == _MomentsCount)
            {
                _GMBinding = new RenderTargetBinding(
                new RenderTargetIdentifier[]
                {
                _B0Handle.Identifier(),
                _B1Handle.Identifier(),
                _B2Handle.Identifier(),
                },
                new RenderBufferLoadAction[]
                {
                RenderBufferLoadAction.DontCare,
                RenderBufferLoadAction.DontCare,
                RenderBufferLoadAction.DontCare,
                },
                new RenderBufferStoreAction[]
                {
                RenderBufferStoreAction.Store,
                RenderBufferStoreAction.Store,
                RenderBufferStoreAction.Store,
                },
                _DepthAttachmentHandle.Identifier(),
                RenderBufferLoadAction.Load,
                RenderBufferStoreAction.DontCare);
            }
            else
            {
                _GMBinding = new RenderTargetBinding(
                new RenderTargetIdentifier[]
                {
                _B0Handle.Identifier(),
                _B1Handle.Identifier(),
                },
                new RenderBufferLoadAction[]
                {
                RenderBufferLoadAction.DontCare,
                RenderBufferLoadAction.DontCare,
                },
                new RenderBufferStoreAction[]
                {
                RenderBufferStoreAction.Store,
                RenderBufferStoreAction.Store,
                },
                _DepthAttachmentHandle.Identifier(),
                RenderBufferLoadAction.Load,
                RenderBufferStoreAction.DontCare);
            }

            _MOITHandle.Init("_MOIT");
            _GIALHandle.Init("_GIAL");
            _RMBinding = new RenderTargetBinding(
                new RenderTargetIdentifier[]
                {
                _MOITHandle.Identifier(),
                _GIALHandle.Identifier(),
                },
                new RenderBufferLoadAction[]
                {
                RenderBufferLoadAction.DontCare,
                RenderBufferLoadAction.DontCare,
                },
                new RenderBufferStoreAction[]
                {
                RenderBufferStoreAction.Store,
                RenderBufferStoreAction.Store,
                },
                _DepthAttachmentHandle.Identifier(),
                RenderBufferLoadAction.Load,
                RenderBufferStoreAction.DontCare
                );
        }


        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
                throw new ArgumentNullException("cmd");
            if (_B0Handle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(_B0Handle.id);
                _B0Handle = RenderTargetHandle.CameraTarget;
            }
            if (_B1Handle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(_B1Handle.id);
                _B1Handle = RenderTargetHandle.CameraTarget;
            }
            if (_B2Handle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(_B2Handle.id);
                _B2Handle = RenderTargetHandle.CameraTarget;
            }
            if (_MOITHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(_MOITHandle.id);
                _MOITHandle = RenderTargetHandle.CameraTarget;
            }
            if (_GIALHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(_GIALHandle.id);
                _GIALHandle = RenderTargetHandle.CameraTarget;
            }
            base.FrameCleanup(cmd);
        }

        public override void Execute(ScriptableRenderer renderer, ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderer == null)
                throw new ArgumentNullException("renderer");

            CommandBuffer cmd = CommandBufferPool.Get(_kRenderOITTag);
            using (new ProfilingSample(cmd, _kRenderOITTag))
            {

                cmd.GetTemporaryRT(_B0Handle.id, _DescriptorFloat);
                cmd.GetTemporaryRT(_B1Handle.id, _DescriptorFloat4);
                if (MomentsCount._8 == _MomentsCount)
                {
                    cmd.GetTemporaryRT(_B2Handle.id, _DescriptorFloat4);
                }
                CoreUtils.SetKeyword(cmd, "_MOMENT8", MomentsCount._8 == _MomentsCount);

                cmd.SetRenderTarget(_GMBinding);
                cmd.ClearRenderTarget(false, true, Color.black);

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                Camera camera = renderingData.cameraData.camera;
                var drawSettings = CreateDrawRendererSettings(camera, SortFlags.None, _RendererConfiguration, renderingData.supportsDynamicBatching);
                
                context.DrawRenderers(renderingData.cullResults.visibleRenderers, ref drawSettings, _OITFilterSettings);

                // Render objects that did not match any shader pass with error shader
                renderer.RenderObjectsWithError(context, ref renderingData.cullResults, camera, _OITFilterSettings, SortFlags.None);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                cmd.GetTemporaryRT(_MOITHandle.id, _Descriptor);
                cmd.GetTemporaryRT(_GIALHandle.id, _Descriptor);
                cmd.SetRenderTarget(_RMBinding);
                cmd.ClearRenderTarget(false, true, Color.black);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                cmd.SetGlobalTexture("_b0", _B0Handle.id);
                cmd.SetGlobalTexture("_b1", _B1Handle.id);
                cmd.SetGlobalTexture("_b2", _B2Handle.id);

                drawSettings.SetShaderPassName(0, new ShaderPassName("ResolveMoments"));
                context.DrawRenderers(renderingData.cullResults.visibleRenderers, ref drawSettings, _OITFilterSettings);
                // Render objects that did not match any shader pass with error shader
                renderer.RenderObjectsWithError(context, ref renderingData.cullResults, camera, _OITFilterSettings, SortFlags.None);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();


                CoreUtils.SetRenderTarget(cmd, 
                    _ColorAttachmentHandle.Identifier(), RenderBufferLoadAction.Load, RenderBufferStoreAction.Store, 
                    ClearFlag.None);
                cmd.Blit(_ColorAttachmentHandle.Identifier(), _ColorAttachmentHandle.Identifier(), renderer.GetMaterial(MaterialHandle.MomentOITComposite));
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}