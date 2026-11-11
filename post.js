// ===== Valtheria — pós-processamento: brilho (bloom), gradação de cor cinematográfica, vinheta, FXAA e efeitos de tela =====
import * as THREE from './three.module.min.js';
import { EffectComposer } from './EffectComposer.js';
import { RenderPass } from './RenderPass.js';
import { UnrealBloomPass } from './UnrealBloomPass.js';
import { OutputPass } from './OutputPass.js';
import { ShaderPass } from './ShaderPass.js';
import { FXAAShader } from './FXAAShader.js';

const GradeShader = {
  uniforms: { tDiffuse: { value: null }, time: { value: 0 }, sat: { value: 1.12 }, contrast: { value: 1.06 }, warm: { value: 0.5 }, vig: { value: 0.32 }, hurt: { value: 0 }, lowHp: { value: 0 }, flash: { value: 0 }, night: { value: 0 }, tint: { value: new THREE.Color(1, 1, 1) }, tintAmt: { value: 0 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform float time, sat, contrast, warm, vig, hurt, lowHp, flash, night, tintAmt; uniform vec3 tint; varying vec2 vUv;
    void main(){
      vec3 c = texture2D(tDiffuse, vUv).rgb;
      float l = dot(c, vec3(.299,.587,.114));
      // saturação e contraste suaves (curva em S)
      c = mix(vec3(l), c, sat - lowHp * .7);
      c = (c - .5) * contrast + .5;
      // tons divididos: sombras frias, luzes quentes (estilo fantasia)
      vec3 shadowT = mix(vec3(.92,.97,1.08), vec3(.85,.9,1.15), night), hiT = vec3(1.06,1.0,.9);
      c *= mix(shadowT, hiT, smoothstep(.2, .85, l) * warm + (1. - warm) * .5);
      // cor do ambiente (pântano, tumba, vazio…)
      c = mix(c, c * tint * 1.15, tintAmt);
      // vinheta + vermelho ao levar dano / vida baixa
      vec2 d = vUv - .5; float r = dot(d, d) * 2.2;
      c *= 1. - vig * smoothstep(.15, 1.1, r);
      float pulse = lowHp * (.55 + .45 * sin(time * 5.));
      c = mix(c, vec3(.55,0.,0.), clamp((hurt * .7 + pulse * .8) * smoothstep(.05, 1.0, r), 0., .85));
      c += flash * vec3(1.,.95,.8) * (1. - r * .4);
      gl_FragColor = vec4(clamp(c, 0., 1.), 1.);
    }`,
};
export const POST = { on: false, composer: null, bloom: null, grade: null, fxaa: null };
export function initPost(renderer, scene, camera) {
  const size = renderer.getDrawingBufferSize(new THREE.Vector2());
  const rt = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: 0 });
  const comp = new EffectComposer(renderer, rt);
  comp.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(size.x / 2, size.y / 2), 0.45, 0.55, 0.86); comp.addPass(bloom);
  comp.addPass(new OutputPass());
  const grade = new ShaderPass(GradeShader); comp.addPass(grade);
  const fxaa = new ShaderPass(FXAAShader); comp.addPass(fxaa);
  Object.assign(POST, { composer: comp, bloom, grade, fxaa, rt, renderer });
  resizePost(); return POST;
}
export function setPostQuality(level) { // alta: bloom + MSAA; media: bloom leve + FXAA; baixa: desligado
  if (!POST.composer) return; POST.on = level !== 'baixa';
  POST.rt.samples = level === 'alta' ? 4 : 0; POST.fxaa.enabled = level !== 'alta'; POST.bloom.enabled = true;
  POST.bloom.strength = level === 'alta' ? 0.5 : 0.38; resizePost();
}
export function resizePost() {
  if (!POST.composer) return; const r = POST.renderer, s = r.getDrawingBufferSize(new THREE.Vector2()), pr = r.getPixelRatio();
  POST.composer.setPixelRatio(pr); POST.composer.setSize(innerWidth, innerHeight);
  POST.fxaa.material.uniforms.resolution.value.set(1 / s.x, 1 / s.y);
}
const G = { hurt: 0, flash: 0 };
export const postHurt = (k = 1) => { G.hurt = Math.min(1, G.hurt + 0.6 * k); };
export const postFlash = (k = 1) => { G.flash = Math.min(0.8, G.flash + 0.35 * k); };
export function renderPost(dt, o) {
  const u = POST.grade.material.uniforms; G.hurt = Math.max(0, G.hurt - dt * 1.8); G.flash = Math.max(0, G.flash - dt * 2.5);
  u.time.value += dt; u.hurt.value = G.hurt; u.flash.value = G.flash; u.lowHp.value = o.lowHp; u.night.value = o.night;
  u.tintAmt.value += ((o.tint ? 0.35 : 0) - u.tintAmt.value) * Math.min(1, dt * 1.5); if (o.tint) u.tint.value.set(o.tint);
  POST.bloom.threshold = 0.86 - o.night * 0.18; // à noite as luzes e magias brilham mais
  POST.composer.render(dt);
}
