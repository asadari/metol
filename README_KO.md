# Metol 한국어 UI

삼성 NX500용 Metol 추가 메뉴를 한국어로 번역한 작업입니다.

**현재 버전: r5 (2026-10-23), 대상: NX500 1.12.**
사용자 포크: [asadari/metol](https://github.com/asadari/metol), 브랜치 `nxwa`.

r4 실기 로그에서 같은 부팅 ID 때문에 자동 복원을 건너뛰는 문제를 확인했고, r5에서 수정했습니다.
메뉴를 열고 선택을 바꾸지 않은 채 ‘저장 후 닫기’를 눌렀을 때 적용하지 않던 문제도 수정했습니다.
**r5 빌드·모의 부팅·ARM/QEMU 버튼 입력 및 화면 검증은 통과했지만, r5 실기 재부팅 검증은 아직 필요합니다.**

현재 LUT 선택은 카메라 내부 `/opt/usr/nx-ks/nxui-state/saved-lut`에 저장합니다.
Metol 시작 시 자동 복원을 시도하며 반셔터로 화면에 반영합니다. 기본값 복원을 누르면 자동 적용도 해제합니다.
진단 로그는 SD 카드 `lut/boot-r5.log`입니다. 아래 r2~r4 설명은 이전 버전의 변경 이력입니다.

## 설치 패키지

`release/Metol-KO-NX500-20261023-r5.zip`을 SD 카드 루트에 풀어
`info.tg`, `nx_cs.adj`, `install.sh`, `scripts/`, `looks/`가 루트에 놓이도록 합니다.
기존 Metol 사용자는 먼저 SD 카드 내용을 백업하세요. 카메라에 넣으면 기존 설치기가 업데이트하며,
NX500에서는 한국어 NXUI를 활성화합니다. 대상 펌웨어는 NX500 1.12입니다.

기본 중국어 레시피 이름은 한국어로 자동 변경하며, 색상 수치와 사용자가 바꾼 이름은 유지합니다.
변경 전 파일은 SD 카드 `filmlab/recipes.json.before-ko`에 한 번 백업합니다.
이름만 복원하려면 해당 백업을 `recipes.json`으로 복사합니다.
기존 UI로 되돌리려면 업데이트 전 백업의 scripts와 기존 설치 파일을 사용합니다.


## 번역 범위

- NXUI 메인 메뉴, FilmLab / LUT 패널, 상태 및 오류 메시지
- NX500 메뉴와 하위 메뉴, 동적으로 생성하는 메뉴의 이동 버튼
- 레시피 이름에 포함된 중국어 표현 (필름 제품명은 유지)
- 주요 설정·촬영·원격 저장 팝업
- 한글 음절 전체와 자모를 지원하는 NXUI_KO 폰트

레시피 키와 색상 수치, 카메라 제어 명령은 유지했습니다.
카메라 순정 메뉴, 웹 갤러리, 개발용 로그, NX1 영문 메뉴는 이 작업의 번역 범위에 포함하지 않습니다.
구형 mod_gui 팝업은 자체 시스템 폰트를 사용하므로 기기에서 한글 표시 확인이 필요합니다.

## 빌드와 적용

기존 빌드 스크립트는 Linux 환경, ARM 크로스 컴파일러, NX500 1.12 rootfs의 라이브러리를 필요로 합니다.
macOS에서 스크립트만 실행해서 빌드할 수는 없습니다.

```sh
cd test_server/nxui
bash prepare_dev.sh
NXUI_ROOTFS=/path/to/rootfs-112 bash build.sh arm
```

빌드 성공 시 `scripts/nxui/nxui.arm`이 갱신됩니다. 새 실행 파일과 `scripts/`의 번역된 메뉴·스크립트,
`scripts/nxui/fonts-ko/` 및 `fonts.conf`를 함께 배포해야 합니다.
기존 설치 방법은 [영문 README](README_EN.md), 업데이트 절차는 [SYNC.md](SYNC.md)를 따릅니다.
설치기의 `update_korean_labels.sh`가 기본 레시피 이름만 갱신합니다.

실기에서 확인할 항목:

1. EV 두 번: 메인 메뉴, 하위 메뉴, 팝업의 한글 표시와 잘림 여부
2. EV+AEL: 레시피 이름, 미리보기, 저장 후 닫기
3. EV+WiFi: LUT 선택, 기본값 복원, 반셔터로 닫기
4. 한글로 이름 붙인 LUT 파일, WiFi/Telnet 상태 표시

## 폰트

Noto Sans CJK KR Regular를 줄여 `NXUI_KO`로 이름을 바꿨습니다.
한글 전체와 GB2312 한자, UI 기호를 포함합니다. 라이선스는
`scripts/nxui/fonts-ko/OFL-NotoSansCJK.txt`에 포함되어 있습니다.

원본: https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean

```sh
python3 -m pip install fonttools
python3 test_server/nxui/make_korean_font.py /path/to/NotoSansCJKkr-Regular.otf
```

한글 폰트는 NX500 1.12 라이브러리와 QEMU/Xvfb에서 메인 메뉴(720×336),
FilmLab 및 LUT(720×208) 렌더링을 확인했습니다. 실제 카메라의 시작 속도와 팝업은 미검증입니다.

빌드 라이브러리는 삼성 공식 NX500 1.12 펌웨어에서 추출했습니다. 펌웨어는 패키지에 넣지 않습니다.
펌웨어 SHA-256: `f4c238e811970cf858b5d734119477ea191d35cd29d9f84b584157ecfc4ee997`.
검증 재실행: `NXUI_ROOTFS=/path/to/rootfs python3 test_server/nxui/verify_korean_display.py`.


추가 검증: Linux 호스트 X11 이벤트 테스트에서 레시피 선택·저장·실패 처리, 체크박스·하위 메뉴,
LUT 복원·스크롤, 서비스 켜기/끄기·부분 실패 후 재시도까지 통과했습니다.

## r2: LUT 데이터 포함 수정

최초 한국어 ZIP은 `looks/`가 누락되어 있었습니다. r2에는 기본 LUT 83개를 포함했습니다.
이미 한국어 UI를 설치했다면 보완 ZIP의 `looks/` 폴더만 SD 카드 루트에 추가하면 됩니다.
같은 이름의 사용자 수정 LUT가 있다면 먼저 백업하고 덮어쓸지 확인하세요.
EV+AEL은 필름 레시피이고, LUT는 EV+WiFi로 엽니다.
LUT 선택 작업이 완료된 후 반셔터를 눌러 적용을 확인하세요.

## r3: 마지막 LUT 기억 및 부팅 복원

- 적용에 성공한 LUT 이름을 SD 카드 `nxui/saved-lut`에 저장합니다. 메뉴도 이 항목을 다시 선택합니다.
- 업데이트 후 원하는 LUT를 한 번 적용하세요. 이후 부팅할 때 카메라 준비 상태를 확인한 뒤 자동으로 다시 씁니다.
- 부팅 후 몇 초 기다렸다가 반셔터를 한 번 눌러 실제 화면에 반영하세요. ISP 강제 리로드는 하지 않습니다.
- 기본값 복원을 누르면 자동 적용도 해제됩니다. 부팅 대기 중 수동 선택이나 복원을 하면 수동 작업이 우선합니다.
- 부팅이 달라지면 이전 RAM 백업을 버리고 현재 부팅의 백업을 새로 만듭니다.
- LUT 파일이 없거나 NX500 1.12가 아니면 자동으로 쓰지 않습니다. 준비 시간 초과 시 수동 선택이 필요합니다.

부팅 로그는 카메라 `/tmp/metol-lut-boot.log`에 남습니다. SD 카드의 `nxui/` 폴더를 지우면 저장한 선택도 없어집니다.
모의 장치에서 성공·실패 저장, 재부팅 복원, 백업 갱신, 복원 해제, 파일 누락, 기종 제한 및 대기 시간 초과를 검증했습니다.
실제 NX500의 부팅 타이밍과 절전 복귀 동작은 아직 검증하지 않았습니다.

## r4: 실기 저장 문제 대응 및 부팅 진단

실기 SD 카드(exFAT)에서 이름이 완전히 같은 `saved-lut`/`last-lut` 디렉터리 항목이 여러 개 발견되었습니다.
이 현상과 부팅 실패 사이의 정확한 인과관계는 아직 확인되지 않았습니다.

- LUT 이름 저장 위치를 카메라 내부 `/opt/usr/nx-ks/nxui-state/`로 변경했습니다. LUT 메뉴도 같은 위치를 읽습니다.
- r3의 SD 선택 기록은 가져오지 않습니다. **업데이트 후 원하는 LUT를 한 번 다시 적용해야 합니다.**
- 저장한 LUT가 있으면 부팅 시 SD 카드의 `looks/` 폴더와 카메라가 준비될 때까지 최대 약 60초 대기합니다.
- 복원 종료 시 진단 로그를 SD 카드 `lut/boot-r4.log`로 복사합니다. 카드가 없으면 내부 `nxui-state/boot.log`에만 남습니다.
- 기존 SD 선택 기록과 사진은 삭제하거나 수리하지 않습니다. 원래 LUT 파일은 계속 SD 카드 `looks/`에서 읽습니다.
- 이전 설명의 SD `nxui/saved-lut` 저장 위치 및 로그 경로는 r3에 해당합니다. r4에서는 위 경로를 사용합니다.

카드가 늦게 준비되는 상황, 내부 저장, 메뉴 실행기의 상태 경로와 부팅 진단 기록을 모의 테스트했습니다.
r4도 실제 카메라에서 재부팅 후 반셔터로 확인해야 하며, 자동 복원이 해결됐다고 아직 보장하지 않습니다.

## r5: 같은 부팅 ID에서 복원 및 저장 버튼 수정

실기 r4 로그에서 `SKIP foreground operation already handled this boot`를 확인했습니다.
전원을 다시 켠 뒤에도 같은 boot-id가 관측되어, 오래된 처리 표시로 자동 복원이 취소되는 조건을 제거했습니다.
현재 자동 복원 작업이 시작된 뒤 발생한 수동 작업만 취소 사유로 사용합니다.
순정 View4 상태에서는 백업을 새로 만들고, 기존 LUT 포인터가 남아 있으면 같은 커널 세션의 원본 백업이 있을 때만 재적용합니다.
알 수 없는 포인터 상태나 다른 부팅의 백업으로는 쓰지 않습니다.

‘저장 후 닫기’는 목록을 움직이지 않았어도 현재 표시된 LUT를 적용하도록 수정했습니다.
r4의 내부 저장 이름은 유지됩니다. 원하는 LUT를 선택하고 저장한 다음 전원을 껐다 켜서 확인하세요.
자동 복원 후 실제 화면 반영에는 반셔터가 필요합니다. 진단 로그는 SD 카드 `lut/boot-r5.log`입니다.
같은 boot-id 및 기존 처리 표시, 순정/수정된 포인터 상태와 ARM에서 실제 저장 버튼 클릭을 회귀 테스트했습니다.
실기 검증은 아직 필요합니다. SD 카드에 남은 r3/r4 로그는 이전 실행 기록입니다.

## r5 검증 재실행 및 패키징

```sh
python3 test_server/nxui/test_lut_persistence.py
python3 test_server/nxui/test_lut_launcher.py
# Linux + Xvfb + qemu-arm + NX500 1.12 rootfs, ARM 빌드 후:
NXUI_ROOTFS=/path/to/rootfs python3 test_server/nxui/verify_korean_display.py
NXUI_ROOTFS=/path/to/rootfs python3 test_server/nxui/test_lut_choice.py
NXUI_ROOTFS=/path/to/rootfs python3 test_server/nxui/test_lut_save.py
python3 test_server/nxui/package_korean.py
```

패키징 스크립트는 로컬 `release/Metol-KO-NX500-20261023-r5.zip` 및 SHA-256 파일을 생성합니다.
생성된 ZIP과 압축 해제 사본은 Git에 넣지 않습니다. GitHub 소스 푸시와 GitHub Release 배포는 별개입니다.
