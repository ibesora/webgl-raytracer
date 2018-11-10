#version 300 es
#define MAX_FLOAT 3.402823466e+38
#define AA_NUM_SAMPLES 16
#define MAX_RANDOM_ITERATIONS 3
#define RAY_BOUNCES 50
#define SPHERE_NUMBER 40

#define PI 3.1415926538

#define LAMBERTIAN 0
#define METAL 1
#define DIELECTRIC 2

precision highp float;


uniform vec2 windowSize;
out vec4 fragmentColor;

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Material {

    uint type;
    vec3 albedo;
    float fuzzyness;
    float refractionIndex;

};

struct HitRecord {
    float t;
    vec3 p;
    vec3 normal;
    Material material;
};

struct Sphere {
    vec3 center;
    float radius;
    Material material;
};

struct Camera {

    vec3 origin;
    vec3 lowerLeftCorner;
    vec3 horizontal;
    vec3 vertical;
    float lensRadius;
    vec3 u, v, w;

};

// https://thebookofshaders.com/10/
float random (vec2 st) {
    return fract(sin(dot(st.xy,
        vec2(12.9898,78.233)))*
        43758.5453123);
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

vec3 randomPointInUnitDisk(vec3 pos) {

    vec3 p;
    do {
        p = 2.0 * vec3(random(pos.xy), random(pos.yz), 0.0) - vec3(1.0, 1.0, 0.0);
    } while((squaredLength(p) >= 1.0));

    return p;

}

Camera getCamera(vec3 lookFrom, vec3 lookAt, vec3 up, float vfov, float aspect, float aperture, float focusDistance) {
    vec3 u, v, w;
    float theta = vfov*PI/180.0;
    float halfHeight = tan(theta/2.0);
    float halfWidth = aspect * halfHeight;
    w = normalize(lookFrom - lookAt);
    u = normalize(cross(up, w));
    v = cross(w, u);
    vec3 lowerLeftCorner = lookFrom - halfWidth*focusDistance*u - halfHeight*focusDistance*v - focusDistance*w;

    return Camera(lookFrom, lowerLeftCorner, 2.0*halfWidth*focusDistance*u, 2.0*halfHeight*focusDistance*v, aperture/2.0, u, v, w);

}

Ray getRay(Camera cam, float u, float v, vec3 rand) {

    vec3 rd = cam.lensRadius * randomPointInUnitDisk(rand);
    vec3 offset = cam.u*rd.x + cam.v*rd.y;

    return Ray(cam.origin + offset, cam.lowerLeftCorner + u * cam.horizontal + v * cam.vertical - cam.origin - offset);

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
            hit.material = s.material;
        }

    }

    return hasHit && inRange;

}

bool hitList(Sphere[SPHERE_NUMBER] spheres, Ray r, float tMin, float tMax, out HitRecord hit) {

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

bool lambertianScatter(Ray rayIn, HitRecord rec, out vec3 attenuation, out Ray scatteredRay) {

    vec3 target = rec.p + rec.normal + randomPointInUnitSphere(rec.p);
    scatteredRay = Ray(rec.p, target - rec.p);
    attenuation = rec.material.albedo;
    return true;

}

bool metalScatter(Ray rayIn, HitRecord rec, out vec3 attenuation, out Ray scatteredRay) {
    
    vec3 reflected = reflect(normalize(rayIn.direction), rec.normal);
    scatteredRay = Ray(rec.p, reflected + rec.material.fuzzyness * randomPointInUnitSphere(rec.p));
    attenuation = rec.material.albedo;
    return (dot(scatteredRay.direction, rec.normal) > 0.0);
}

float schlick(float cosine, float refractionIndex) {

    float r0 = (1.0 - refractionIndex) / (1.0 + refractionIndex);
    r0 = r0*r0;
    return r0 * (1.0 - r0)*pow((1.0 - cosine), 5.0);

}

bool dielectricScatter(Ray rayIn, HitRecord rec, out vec3 attenuation, out Ray scatteredRay) {

    vec3 outwardNormal;
    float niOverNt;
    vec3 refracted;
    float reflectProbability = 1.0;
    float cosine;
    vec3 reflected = reflect(rayIn.direction, rec.normal);
    
    attenuation = vec3(1.0);
    if(dot(rayIn.direction, rec.normal) > 0.0) {

        outwardNormal = -rec.normal;
        niOverNt = rec.material.refractionIndex;
        cosine = rec.material.refractionIndex * dot(rayIn.direction, rec.normal) / length(rayIn.direction);

    } else {

        outwardNormal = rec.normal;
        niOverNt = 1.0 / rec.material.refractionIndex;
        cosine = -dot(rayIn.direction, rec.normal) / length(rayIn.direction);

    }

    refracted = refract(normalize(rayIn.direction), normalize(outwardNormal), niOverNt);
    bool isRefracted = refracted.x != 0.0 || refracted.y != 0.0 || refracted.z != 0.0;

    if(isRefracted) {
        reflectProbability = schlick(cosine, rec.material.refractionIndex);
    }

    if(random(rec.p.xy) < reflectProbability) {
        scatteredRay = Ray(rec.p, reflected);
    } else {
        scatteredRay = Ray(rec.p, refracted);
    }

    return true;

}

vec3 color(Ray r, Sphere[SPHERE_NUMBER] world) {

    HitRecord rec;
    bool hasFinished = false;
    Ray currentRay = r;
    vec3 attenuation = vec3(1.0);
    vec3 color = vec3(0.0);

    for(int bounce = 0; bounce < RAY_BOUNCES && !hasFinished; ++bounce) {

        if(hitList(world, currentRay, 0.001, MAX_FLOAT, rec)) {

            bool keepBouncing = false;
            vec3 materialAttenuation = vec3(1.0);
            Ray scatteredRay = Ray(vec3(0.0), vec3(0.0));

            if(rec.material.type == uint(LAMBERTIAN)) {

                keepBouncing = lambertianScatter(currentRay, rec, materialAttenuation, scatteredRay);


            } else if(rec.material.type == uint(METAL)) {

                keepBouncing = metalScatter(currentRay, rec, materialAttenuation, scatteredRay);

            } else if(rec.material.type == uint(DIELECTRIC)) {

                keepBouncing = dielectricScatter(currentRay, rec, materialAttenuation, scatteredRay);

            }

            if(keepBouncing) {

                currentRay = scatteredRay;
                attenuation *= materialAttenuation;

            } else {

                color = vec3(0.0);
                hasFinished = true;

            }

        } else {

            vec3 unitVector = normalize(r.direction);
            float t = minus2Positive(unitVector.y);
            color = (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
            hasFinished = true;

        }

    }

    return attenuation * color;

}

Sphere[SPHERE_NUMBER] randomScene() {

    Sphere world[SPHERE_NUMBER];

    world[0] = Sphere(vec3(0.0, -1000.0, 0.0), 1000.0, Material(uint(LAMBERTIAN), vec3(0.5, 0.5, 0.5), 0.0, 0.0));
    int index = 1;

    for(int a = -6; a<6; a+=2) {
        for(int b = -6; b<6; b+=2) {
            vec3 center = vec3(float(a)+0.9*random(vec2(float(a)+11.0/22.0, float(b)+11.0/22.0)), 0.2, float(b)+0.9*random(vec2(float(b)+11.0/22.0, float(a)+11.0/22.0)));
            float randMat = random(center.xy);
            if(length(center - vec3(4, 0.2, 0.0)) > 0.9) {
                if(randMat < 0.6) {
                    world[index++] = Sphere(center, 0.2, Material(uint(LAMBERTIAN), vec3(random(center.xy)*random(center.yx), random(center.yz)*random(center.zy), random(center.zx)*random(center.xz)), 0.0, 0.0));
                } else if(randMat < 0.9) {
                    world[index++] = Sphere(center, 0.2, Material(uint(METAL), vec3(0.5*(1.0 + random(center.xy), 0.5*(1.0 + random(center.yz), 0.5*(1.0 + random(center.zx))))), 0.5*random(center.xz), 0.0));
                } else {
                    world[index++] = Sphere(center, 0.2, Material(uint(DIELECTRIC), vec3(0.0, 0.0, 0.0), 0.0, 1.5));
                }
            }
        }
    }

    world[index++] = Sphere(vec3(0.0, 1.0, 0.0), 1.0, Material(uint(DIELECTRIC), vec3(0.0, 0.0, 0.0), 0.0, 1.5));
    world[index++] = Sphere(vec3(-4.0, 1.0, 0.0), 1.0, Material(uint(LAMBERTIAN), vec3(0.4, 0.2, 0.1), 0.0, 0.0));
    world[index++] = Sphere(vec3(4.0, 1.0, 0.0), 1.0, Material(uint(METAL), vec3(0.7, 0.6, 0.5), 0.0, 0.0));

    return world;

}

void main(void) {

    vec3 cameraOrigin = vec3(14.0, 2.0, 4.0);
    vec3 cameraLookAt = vec3(0.0, 1.0, 0.0);
    float distToFocus = length(cameraLookAt - cameraOrigin);
    float radius = cos(PI/4.0);
    Camera cam = getCamera(cameraOrigin, cameraLookAt, vec3(0.0, 1.0, 0.0), 20.0, windowSize.x/windowSize.y, 0.1, distToFocus);

    Sphere[SPHERE_NUMBER] world = randomScene();
    
    vec3 col = vec3(0.0, 0.0, 0.0);
    
    for(int i=0; i<AA_NUM_SAMPLES; ++i) {

        float randX = random((gl_FragCoord.xy + float(i))/windowSize.xy);
        float randY = random((gl_FragCoord.yx + float(i))/windowSize.yx);
        float randZ = random((gl_FragCoord.xy + float(i))/windowSize.yx);
        vec2 uv = (gl_FragCoord.xy + vec2(randX, randY)) / windowSize.xy;
        Ray r = getRay(cam, uv.x, uv.y, vec3(randX, randY, randZ));
        col += color(r, world);

    }

    vec3 nonGammaCorrectedColor = col / float(AA_NUM_SAMPLES);
    fragmentColor = vec4(sqrt(nonGammaCorrectedColor), 1.0);

}