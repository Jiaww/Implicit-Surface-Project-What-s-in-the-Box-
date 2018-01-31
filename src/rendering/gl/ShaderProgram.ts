import {vec2, vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';
import {controls} from '../../main';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;

  unifView: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifResolution: WebGLUniformLocation;
  unifSpiderTrig: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    // Raymarcher only draws a quad in screen space! No other attributes
    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");

    // TODO: add other attributes here
    this.unifView   = gl.getUniformLocation(this.prog, "u_View");
    this.unifTime   = gl.getUniformLocation(this.prog, "u_Time");
    this.unifResolution = gl.getUniformLocation(this.prog, "u_Resolution");
    this.unifSpiderTrig = gl.getUniformLocation(this.prog, "u_SpiderTrig");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  // TODO: add functions to modify uniforms
  setTime(time: number){
    this.use();
    if (this.unifTime != -1){
      gl.uniform1f(this.unifTime, time);
    }
  }

  setResolution(resolution: vec2){
    this.use();
    if (this.unifResolution != -1){
      gl.uniform2fv(this.unifResolution, resolution);
    }
  }

  setSpiderTrig(spiderTrig: boolean){
    this.use();
    if(this.unifSpiderTrig != -1){
      if (spiderTrig)
        gl.uniform1f(this.unifSpiderTrig, 1.0);
      else
        gl.uniform1f(this.unifSpiderTrig, 0.0);
    }
  }

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);

  }
};

export default ShaderProgram;
