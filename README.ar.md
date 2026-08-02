# مخططات QuenchWorks

[English](README.md) · **العربية** · [Español](README.es.md)

<p align="center">
  <a href="https://quench-works.com/images"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/images.json" alt="images"></a>
  <a href="https://quench-works.com/charts"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/charts.json" alt="charts"></a>
  <a href="https://quench-works.com/security"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/cves.json" alt="open CVEs"></a>
  <a href="https://github.com/wolfi-dev"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/wolfi.json" alt="built from source"></a>
  <a href="https://docs.sigstore.dev/"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/cosign.json" alt="signed with cosign"></a>
  <a href="https://quench-works.com/images"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/multiarch.json" alt="multi-arch"></a>
  <a href="https://artifacthub.io/packages/search?org=quenchworks"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/artifacthub.json" alt="ArtifactHub"></a>
  <a href="https://github.com/quenchworks"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/license.json" alt="license"></a>
</p>

مخططات Helm بأسلوب الغرفة النظيفة لكتالوج [QuenchWorks](https://github.com/quenchworks). كل مخطط ينشر صورة مُحصَّنة بصفر ثغرات (0-CVE) من مصنع [images](https://quench-works.com/images)، ويثبّتها بصرامة بواسطة بصمة `sha256`، ويُشحن كأداة OCI موقّعة بـ cosign على GHCR، ومُدرَج على ArtifactHub كـ **ناشر موثَّق** مع مخطط Values.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks في الطرفية: تشغيل صورة بصفر ثغرات، والتحقق منها باستخدام cosign، ونشر مخطط Helm، ومراقبة وصول الـ pod إلى حالة Running." width="760"></a>
</p>

**50+ مخططًا.** بلا جدار دفع، بلا حساب، بلا احتكار مورّد. تصفّحها جميعًا على [quench-works.com/charts](https://quench-works.com/charts).

```bash
helm install cache oci://ghcr.io/quenchworks/charts/redis
```

هذا هو التثبيت بأكمله. الصورة التي ينشرها موقّعة ومثبّتة على بصمة بالفعل، فلا حاجة لأن تتتبع أمان الصورة بنفسك.

## نموذج الأمان

ثلاثة ضمانات، مدمجة في كل مخطط:

- **مثبّت بالبصمة، دائمًا.** تحل المخططات الصور بواسطة `repository@sha256:...`، وليس بواسطة الوسم أبدًا. يُرفض المرجع المعتمد على الوسم فقط عن قصد، بحيث لا يمكن لمخطط فيزيائيًا أن يشحن صورة غير مثبّتة.
- **خط أساس مُحصَّن واحد.** يرث كل مخطط نفس سياق أمان الـ pod والحاوية من مخطط مكتبة [`quench-common`](https://github.com/quenchworks/common): غير جذري، نظام ملفات جذري للقراءة فقط، لا تصعيد للامتيازات، إسقاط كل القدرات، seccomp ‏`RuntimeDefault`. أصلحه مرة واحدة، يُصلَح في كل مكان.
- **مصدر قابل للتحقق.** المخططات موقّعة بـ cosign بلا مفتاح، والصور التي تشير إليها موقّعة وتحمل SBOM. يمكنك التحقق من كل ذلك بنفسك.

## الكائنات المشتركة وIngress اختياري

خمس عائلات من الملفات كانت شبه متطابقة في كل مخطط تُصاغ الآن من مكتبة [`quench-common`](https://github.com/quenchworks/common) بدل نسخة داخل كل مخطط: `ServiceAccount`، وRBAC (`Role`/`RoleBinding`، واختياريًا على مستوى العنقود)، و`PodDisruptionBudget`، و`HorizontalPodAutoscaler`، و`NetworkPolicy`. أصلِح واحدة، فتُصلَح في الكتالوج كله.

تحديد ما انتقل جاء بالقياس لا بالتفضيل: بتجميع المخططات الـ138 حسب الشكل الناتج، `serviceaccount.yaml` متطابق في 117 من 132، و`poddisruptionbudget.yaml` في 105 من 123، و`rbac.yaml` في 104 من 123، و`hpa.yaml` في 20 من 23. أما `NetworkPolicy` فمشتركة لكنها **ذات مُعامِلات**، لأن 128 مخططًا أنتجت 91 شكلًا مختلفًا — فكل تطبيق يسمح بمنافذ مختلفة. و`service.yaml` تبقى عن قصد داخل كل مخطط: 98 شكلًا مختلفًا من 128 مخططًا، لأن قائمة المنافذ هي هوية التطبيق، وأي مساعد سيحتاج إعدادات بحجم الملف الذي يستبدله.

كل مخطط يخدم HTTP لديه **Ingress معطَّل افتراضيًا**:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com      # المضيف بلا `paths` يحصل على مسار "/" بنوع Prefix
  tls:
    - hosts: [app.example.com]
      secretName: app-tls
```

يُحلّ منفذ الخدمة من شكل الخدمة الذي يستخدمه المخطط، فالمضيف وحده يكفي عادةً. وتمكينه بلا مضيف، أو حيث لا يمكن تحديد منفذ HTTP، يُفشِل القالب برسالة واضحة بدل تثبيت شيء لا يوجِّه إلى أي مكان.

المخططات التي **لا** تتحدث HTTP — PostgreSQL وRedis وKafka وMariaDB وetcd — لا تملك مفتاح `ingress` إطلاقًا. فـ `Ingress` موجِّه HTTP ولا يمكنه أن يتقدمها؛ اعرضها عبر `service.type=LoadBalancer` أو تمرير TCP في وحدة التحكم. ومفتاح لا يفعل شيئًا بصمت أسوأ من عدم وجوده.

أما **الحِزم** (stacks) فلا تملك خدمة خاصة بها، لذا يتقدّم `ingress` فيها خدمةَ مخطط فرعي — واجهة الحزمة الأساسية افتراضيًا (Grafana، أو Keycloak في `identity-stack`) — ويوجّهه `ingress.serviceName` / `ingress.servicePort` إلى أي مكوّن آخر. ويمكنك بدلًا من ذلك تركه معطلًا وتمكين ingress المخطط الفرعي نفسه، مثل `grafana.ingress.enabled=true`.

وإلى جانب ذلك يكشف كل مخطط `commonLabels` و`commonAnnotations` و`podLabels` (وكلها آمنة للتغيير على إصدار حيّ)، إضافةً إلى `partOf` و`fullnameOverride` و`image.registry` و`imagePullSecrets`. ويوجد `selectorLabels` أيضًا، لكنه يغذّي `spec.selector` الذي يعتبره Kubernetes **غير قابل للتغيير** — اضبطه قبل أول تثبيت وإلا فشل كل `helm upgrade` لاحق برسالة `field is immutable`.

## الكتالوج

| الفئة | المخططات |
|----------|--------|
| علائقية | `postgresql` · `mariadb` · `mysql` · `cockroachdb` ⚠️ |
| مستندية | `couchdb` · `ferretdb` · `documentdb` · `postgres-documentdb` · `mongodb` ⚠️ |
| واسعة الأعمدة | `cassandra` · `scylladb` |
| مفتاح-قيمة / ذاكرة مؤقتة | `valkey` · `redis` · `memcached` · `dragonfly` ⚠️ |
| بحث / متجهات | `opensearch` · `solr` · `meilisearch` · `qdrant` · `elasticsearch` ⚠️ |
| سلاسل زمنية | `influxdb` · `victoriametrics` |
| تحليلية | `clickhouse` |
| رسوم بيانية | `neo4j` |
| المراسلة / البث | `kafka` · `nats` · `rabbitmq` · `pulsar` |
| التنسيق | `etcd` · `zookeeper` · `temporal` |
| المراقبة | `prometheus` · `grafana` · `loki` · `tempo` · `otel-collector` · `vector` · `fluent-bit` |
| البوابات / الوكلاء | `nginx` · `caddy` · `traefik` · `haproxy` |
| تخزين الكائنات | `garage` · `rustfs` · `seaweedfs` |
| الأسرار / الهوية | `openbao` · `keycloak` |
| السجل · Git · التكامل المستمر/البنية التحتية ككود | `harbor` · `gitea` · `atlantis` |

⚠️ = متاح المصدر، **ليس** برمجيات مفتوحة المصدر معتمدة من OSI (راجع [الترخيص](#a-note-on-licensing)).

## التحقق من مخطط

```bash
cosign verify ghcr.io/quenchworks/charts/postgresql@sha256:DIGEST \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## وثائق كل مخطط

يعرض GitHub ملف README الوحيد لهذا المستودع على صفحة حزمة كل مخطط؛ ولا يمكنه عرض ملف README لكل مخطط لأدوات OCI. توجد وثائق كل مخطط الخاصة (القيم، الأمثلة، ملاحظات الأمان) على **ArtifactHub** وتُشحن داخل المخطط نفسه:

```bash
helm show readme oci://ghcr.io/quenchworks/charts/<chart>
```

## التخطيط

```
quench/<app>/             one app chart per directory, e.g. quench/postgresql
.github/workflows/        release (lint, install, package, push) and digest repin
```

يوجد مخطط مكتبة `quench-common` المشترك في مستودعه الخاص، [quenchworks/common](https://github.com/quenchworks/common)، المنشور على `oci://ghcr.io/quenchworks/charts/quench-common`. تعتمد عليه مخططات التطبيقات وتسحبه وقت البناء، لذا فهو غير مُضمَّن هنا.

## كيف تعمل الإصدارات

يبني مصنع الصور صورة ويوقّعها، ثم يطلق إرسال `image-published` إلى هذا المستودع. يعيد `on-digest.yml` تثبيت ملف `values.yaml` الخاص بالمخطط على البصمة الجديدة ويُجري الإيداع. تلك الدفعة تُشغّل `release-<app>.yml`، الذي يفحص ويُولّد القوالب ويثبّت في عنقود kind ويُجري جولة عميل حقيقية كبوابة، ثم يحزم ويدفع مخطط OCI الموقّع بـ cosign وينشر بيانات ArtifactHub الوصفية.

## قاعدة الغرفة النظيفة

تُكتب المخططات هنا من وثائق المنبع الخاصة بكل تطبيق. وهي غير منسوخة أو مقتبسة من مخططات أي مورّد آخر. راجع [CONTRIBUTING](https://github.com/quenchworks/.github/blob/main/CONTRIBUTING.md).

## ملاحظة حول الترخيص

معظم الكتالوج نظيف من ناحية OSI. أربعة مخططات تغلّف مخازن بيانات متاحة المصدر وتحمل لافتة ترخيص بارزة في ملف README وملف NOTES وعلى الموقع، لأنها **ليست** برمجيات مفتوحة المصدر معتمدة من OSI. يسمّي كلٌّ منها البديل النظيف الذي نوصي به بدلًا منه:

| المخطط | الترخيص | البديل النظيف |
|-------|---------|-------------------|
| `mongodb` | SSPL-1.0 | `ferretdb` + `documentdb` (متوافق مع بروتوكول MongoDB، ومفتوح حقًا) |
| `elasticsearch` | SSPL-1.0 | `opensearch` (نسخة Apache-2.0 بديلة جاهزة) |
| `cockroachdb` | BUSL-1.1 | `postgresql` لـ SQL أحادي المنطقة (يتحول BUSL إلى Apache بعد 3 سنوات) |
| `dragonfly` | BUSL-1.1 | `valkey` (BSD-3-Clause، متوافق مع Redis) |

## الترخيص

MIT لقوالب المخططات والأدوات. يحمل كل تطبيق منشور ترخيص المنبع الخاص به.
