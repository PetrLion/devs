Backlog and Roles

Backlog (high-level)
1. Ініціалізувати репозиторій, додати базові файли (.gitignore, README, Makefile).
2. Скопіювати `src/41_scan_stream_default.py` з зовнішнього репозиторію.
3. Налаштувати гілки `dev`, `stage`, `main`; заборонити прямий push у `main`.
4. Додати GitHub Actions: build+release (Cosign keyless, SBOM), Scorecard, Grype.
5. Оформити реліз v1.0.0 з артефактами і SBOM.
6. Провести перевірки Scorecard і Grype, виправити знайдені питання (за потребою).
7. Документація: README оновити алгоритмом; журнал кроків `steps.txt`.

Roles
- PO: формує таски, пріоритизує, організує оцінку в Planning Poker (https://planningpokeronline.com/).
- Dev/DevOps: реалізують пайплайни, збірку, реліз, безпекові перевірки.
- Tech Writer: документує процес і бере участь у всіх активностях.

Sprint Planning (estimate pointers)
- Кожен пункт backlog оцінити плануванням (story points) та визначити спринтову потужність.


