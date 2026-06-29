# مخططات QuenchWorks

[English](README.md) · **العربية** · [Español](README.es.md)

<p align="center">
  <a href="https://quench-works.com/images"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/images.json" alt="hardened images"></a>
  <a href="https://quench-works.com/charts"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/charts.json" alt="signed charts"></a>
  <a href="https://quench-works.com/security"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/cves.json" alt="open CVEs"></a>
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
