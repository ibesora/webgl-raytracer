#version 300 es

precision highp float;

uniform vec2 windowSize;
out vec4 fragmentColor;

struct Ray {
    vec3 origin;
    vec3 direction;
};

vec3 cameraOrigin = vec3(0.0, 0.0, 0.0);
vec3 cameraLowerLeftCorner = vec3(-2.0, -1.0, -1.0);
vec3 cameraHorizontal = vec3(4.0, 0.0, 0.0);
vec3 cameraVertical = vec3(0.0, 2.0, 0.0);

Ray getRay(float u, float v) {

  return Ray(cameraOrigin, cameraLowerLeftCorner + u * cameraHorizontal + v * cameraVertical);

}

vec3 color(Ray r) {
    vec3 unitVector = normalize(r.direction);
    float t = 0.5*(unitVector.y + 1.0);
    return (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
}

void main(void) {

    float u = gl_FragCoord.x / windowSize.x;
    float v = gl_FragCoord.y / windowSize.y;
    Ray r = getRay(u, v);
    fragmentColor = vec4(color(r), 1.0);
}