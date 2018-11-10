#version 300 es
#define MAX_FLOAT 3.402823466e+38
#define AA_NUM_SAMPLES 16
#define MAX_RANDOM_ITERATIONS 3
#define RAY_BOUNCES 5
precision highp float;


uniform vec2 windowSize;
out vec4 fragmentColor;

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct HitRecord {
    float t;
    vec3 p;
    vec3 normal;
};

struct Sphere {
    vec3 center;
    float radius;
};

struct Camera {

    vec3 origin;
    vec3 lowerLeftCorner;
    vec3 horizontal;
    vec3 vertical;

};

// https://thebookofshaders.com/10/
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

Ray getRay(Camera cam, float u, float v) {

    return Ray(cam.origin, cam.lowerLeftCorner + u * cam.horizontal + v * cam.vertical);

}

vec3 rayAtDistance(Ray r, float distance) {

    return r.origin + r.direction * distance;

}

bool hitSphere(Sphere s, Ray r, float tMin, float tMax, out HitRecord hit) {

    vec3 oc = r.origin - s.center;
    float a = dot(r.direction, r.direction);
    float b = dot(oc, r.direction);
    float c = dot(oc, oc) - s.radius*s.radius;
    float discriminant = b*b - a*c;
    bool hasHit = (discriminant > 0.0);
    bool inRange = false;

    if(hasHit) {
        float sqrtDiscriminant = sqrt(discriminant);
        float t = (-b - sqrtDiscriminant) / a;
        inRange = tMin < t && t < tMax;

        if(!inRange) {
            t = (-b + sqrtDiscriminant) / a;
            inRange = tMin < t && t < tMax;
        }

        if(inRange) {
            hit.t = t;
            hit.p = rayAtDistance(r, t);
            hit.normal = (hit.p - s.center) / s.radius;
        }

    }

    return hasHit && inRange;

}

bool hitList(Sphere[2] spheres, Ray r, float tMin, float tMax, out HitRecord hit) {

    HitRecord temp;
    bool hitAnything = false;
    float closest = tMax;

    for(int i=0; i<spheres.length(); ++i) {

        if(hitSphere(spheres[i], r, tMin, closest, temp)) {

            hitAnything = true;
            closest = temp.t;
            hit = temp;

        }

    }

    return hitAnything;

}

float minus2Positive(float value) {
    return 0.5 * (value + 1.0);
}

vec3 minus2Positive(vec3 vec) {
    return vec3(minus2Positive(vec.x), minus2Positive(vec.y), minus2Positive(vec.z));
}

float squaredLength(vec3 v) {
    return dot(v, v);
}

vec3 randomPointInUnitSphere(vec3 pos) {

    vec3 p;
    int iters = 0;
    do {
        p = vec3(random(pos.xy), random(pos.yz), random(pos.xz));
        iters++;
    } while((squaredLength(p) >= 1.0) && iters < MAX_RANDOM_ITERATIONS);

    return p;

}

vec3 color(Ray r, Sphere[2] world) {

    HitRecord rec;
    bool hasFinished = false;
    Ray currentRay = r;
    float contribution = 1.0;
    vec3 color;

    for(int bounce = 0; bounce < RAY_BOUNCES && !hasFinished; ++bounce) {

        if(hitList(world, currentRay, 0.001, MAX_FLOAT, rec)) {

            vec3 target = rec.p + rec.normal + randomPointInUnitSphere(rec.p);
            currentRay = Ray(rec.p, target - rec.p);
            contribution *= 0.5;

        } else {

            vec3 unitVector = normalize(r.direction);
            float t = minus2Positive(unitVector.y);
            color = (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
            hasFinished = true;

        }

    }

    return contribution * color;

}

void main(void) {

    vec3 cameraOrigin = vec3(0.0, 0.0, 0.0);
    vec3 cameraLowerLeftCorner = vec3(-2.0, -1.0, -1.0);
    vec3 cameraHorizontal = vec3(4.0, 0.0, 0.0);
    vec3 cameraVertical = vec3(0.0, 2.0, 0.0);

    Camera cam = Camera(cameraOrigin, cameraLowerLeftCorner, cameraHorizontal, cameraVertical);
    Sphere world[2];
    world[0] = Sphere(vec3(0.0, 0.0, -1.0), 0.5);
    world[1] = Sphere(vec3(0.0, -100.5, -1.0), 100.0);
    
    vec3 col = vec3(0.0, 0.0, 0.0);
    
    for(int i=0; i<AA_NUM_SAMPLES; ++i) {

        float randX = random((gl_FragCoord.xy + float(i))/windowSize.xy);
        float randY = random((gl_FragCoord.yx + float(i))/windowSize.yx);
        vec2 uv = (gl_FragCoord.xy + vec2(randX, randY)) / windowSize.xy;
        Ray r = getRay(cam, uv.x, uv.y);
        col += color(r, world);

    }

    vec3 nonGammaCorrectedColor = col / float(AA_NUM_SAMPLES);
    fragmentColor = vec4(sqrt(nonGammaCorrectedColor), 1.0);

}