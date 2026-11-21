# SteelSeries Audio Fix

[English](#english) · [Polski](#polski)

Windows 11 audio diagnostics and recovery for SteelSeries GG, Sonar and other playback devices. Diagnose missing sound, check audio services, select an output and restore a saved configuration.

> **Experimental prototype:** not yet validated on a real Windows 11 PC with a SteelSeries headset. It cannot guarantee a fix; see the [Windows test plan](docs/TESTY-WINDOWS.md).

## Polski

Lokalny program diagnostyczny dla Windows 11, przeznaczony przede wszystkim dla osób korzystających ze SteelSeries GG i Sonar. Pomaga ustalić, czy problem dotyczy urządzenia Windows, usług audio czy konfiguracji Sonar, i oferuje wybrane naprawy. Projekt jest niezależny od SteelSeries i Microsoftu.

**Status: prototyp wymagający testu na rzeczywistym Windows 11 i słuchawkach.** Nie ma gwarancji naprawy każdej usterki. Przed udostępnieniem szerszemu gronu przetestuj scenariusze opisane w [planie testów](docs/TESTY-WINDOWS.md).

## Uruchomienie

1. Pobierz wszystkie pliki projektu jako ZIP z GitHuba przez **Code → Download ZIP** i rozpakuj je do jednego folderu. Program uruchamia się na komputerze z problemem, nie na GitHubie.
2. Podłącz i włącz słuchawki lub odbiornik USB. Zamknij głośne aplikacje i zdejmij słuchawki przed testami głośności.
3. Uruchom `Start.cmd` dwukrotnym kliknięciem. Najpierw wybierz diagnostykę, przeczytaj wynik i dopiero potem zdecyduj o naprawie. Wybrane operacje usług Windows wymagają uruchomienia jako administrator.
4. Przy korzystaniu z Sonar otwórz GG → Sonar → Mixer i sprawdź, czy fizyczne słuchawki są wybrane jako wyjście właściwych kanałów. Sprawdź również mikser głośności oraz ustawienia gry lub Discorda.

Menu pozwala wybrać domyślne wyjście Windows dla zwykłego dźwięku i multimediów, ustawić poziom wybranego wyjścia na 0–35% i zdjąć jego wyciszenie, a także spróbować uruchomić zatrzymane usługi audio. Przed każdą operacją program prosi o potwierdzenie i zapisuje kopię w `%LOCALAPPDATA%\SteelSeriesFix\Backups`. Rola komunikacji pozostaje bez zmian przy wyborze wyjścia. Opcja przywracania odtwarza zapisane dostępne wyjścia, poziomy i wyciszenie; może podnieść głośność i nie cofa stanu usług. Kopia wykonana przed uruchomieniem usług zawiera tylko ich stan i nie służy do przywracania wyjść.

Diagnostykę bez interaktywnego menu można uruchomić z Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\SteelSeriesFix.ps1 -DiagnoseOnly
```

`ExecutionPolicy Bypass` dotyczy wyłącznie tego procesu. Nie pobieraj i nie uruchamiaj skryptów z nieznanych źródeł ani poleceń wklejanych bez sprawdzenia.

## Jak rozumieć problem

Sonar dodaje do Windows wirtualne urządzenia, np. Gaming i Chat. Dźwięk przechodzi z aplikacji przez wybrany kanał Sonar, a następnie do fizycznego urządzenia wskazanego w mikserze GG. Domyślne wyjście Windows, ustawienie aplikacji i fizyczne wyjście Sonar to osobne elementy. SteelSeries opisuje też wybór Gaming jako wyjścia domyślnego i Chat dla komunikacji w [instrukcji konfiguracji Sonar](https://support.steelseries.com/hc/en-us/articles/16956050580109-How-to-set-up-Sonar).

Jeśli Sonar kieruje dźwięk w złe miejsce, sprawdź w GG ustawienia **Device Manager**, kolejność urządzeń i Backup Device Switch. [Instrukcja SteelSeries](https://support.steelseries.com/hc/en-us/articles/34430664112909-Sound-Device-Manager) wyjaśnia działanie list i kanałów. Alternatywnie można wybrać fizyczne słuchawki bezpośrednio jako wyjście Windows, tymczasowo omijając Sonar; aplikacje przypisane do innych urządzeń mogą wymagać osobnej zmiany.

Jeśli nadal nie słychać dźwięku, sprawdź wyciszenie na słuchawkach, USB lub odbiornik, mikser aplikacji, format i ulepszenia dźwięku oraz uruchom narzędzie diagnostyczne Windows. Dalsze kroki opisuje [pomoc Microsoftu](https://support.microsoft.com/en-us/windows/hardware/audio/fix-sound-or-audio-problems-in-windows).

## Granice i prywatność

- Program nie konfiguruje wewnętrznego routingu, EQ ani mikrofonu w Sonar, nie instaluje sterowników i nie resetuje konfiguracji GG. Dane per aplikacja i fizyczne regulatory słuchawek również wymagają osobnego sprawdzenia.
- Odczyt urządzeń i głośności korzysta z Windows Core Audio. Zmiana domyślnego wyjścia opiera się na **nieudokumentowanym interfejsie Windows PolicyConfig**; może przestać działać po aktualizacji Windows. Gdy zawiedzie, użyj ustawień dźwięku Windows albo przycisku ustawienia urządzeń w GG.
- Oficjalny [SteelSeries GameSense SDK](https://github.com/SteelSeries/gamesense-sdk) opisuje integracje urządzeń, lecz nie stanowi udokumentowanego API konfiguracji routingu Sonar. Program nie korzysta z nieoficjalnego API Sonar.
- Raporty i kopie stanu mogą zawierać nazwy urządzeń i identyfikatory. Przed przesłaniem ich komukolwiek przejrzyj ich zawartość. Program nie ma funkcji wysyłania danych.

## Rozwój

Kod źródłowy jest w `src/`, testy w `tests/`, a kontrola składni i testy bez zmian urządzeń są przygotowane dla GitHub Actions. Program wymaga Windows PowerShell 5.1 lub PowerShell 7 na Windows; nie działa na macOS. Nie wymaga instalowania zewnętrznych modułów PowerShell.


## English

SteelSeries Audio Fix is an independent, local Windows audio troubleshooting prototype. It is intended for missing sound and output routing problems involving SteelSeries GG, Sonar, headsets and other playback devices. It is not affiliated with SteelSeries or Microsoft.

### What it does

- Inspects active playback endpoints, default roles, volume, mute, Windows audio services and detected SteelSeries/Sonar devices.
- After confirmation, selects a Windows playback endpoint for the console and multimedia roles, adjusts the selected endpoint's volume within 0–35% and unmutes it, or tries to start stopped audio services.
- Saves a separate local snapshot before each change. Playback settings can be restored for devices still available. Restoration can raise volume to its previous value; it does not revert service state.
- Does not install drivers, reset GG, change microphone settings or modify Sonar's internal mixer. The default communications role is left untouched when selecting an output.

### Get started

1. Download the repository with **Code → Download ZIP**, extract it, and connect your headset or USB receiver.
2. Run `Start.cmd` on the affected Windows 11 PC. Review the diagnosis before selecting an action. Starting stopped services may require running as administrator.
3. If using Sonar, open **GG → Sonar → Mixer** and select the physical headset for the relevant channel. Check per-app routing and hardware mute controls as well.

The tool uses Windows Core Audio to inspect devices. Changing the default endpoint uses the undocumented Windows PolicyConfig interface and could stop working after a Windows update. It does not read or configure Sonar's internal routing. Snapshots are stored under `%LOCALAPPDATA%\SteelSeriesFix\Backups` and may contain device names and IDs; review them before sharing. Nothing is sent by the program.

The Windows smoke workflow checks PowerShell syntax, compiles the interop code and runs a read-only diagnosis. It cannot prove that physical audio works. See the [Windows test plan](docs/TESTY-WINDOWS.md) for manual checks.
