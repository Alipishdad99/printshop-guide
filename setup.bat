@echo off
rem ====================================================================
rem  Printshop - one-click setup  (Windows 7 SP1 and newer, 64-bit and 32-bit)
rem
rem  Double-click this file. It does everything by itself:
rem    1. Visual C++ runtime        4. Git (for downloads and updates)
rem    2. XAMPP 7.4 in C:\xampp     5. access key for this computer,
rem    3. Apache + MySQL start         then waits for the seller to approve it
rem       with Windows              6. downloads the program
rem                                 7. installs it and opens it in the browser
rem
rem  Installer files are taken from this folder if they are already here
rem  (e.g. from a USB stick); otherwise they are downloaded from the
rem  official sites. Running it again is safe: finished steps are skipped.
rem
rem  Guide (Persian): https://github.com/Alipishdad99/printshop-guide
rem ====================================================================
setlocal EnableExtensions
title Printshop setup

rem ---------- run as Administrator ----------
net session >nul 2>&1
if errorlevel 1 (
  echo Asking for Administrator permission - click Yes...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
cd /d "%HERE%"

set "XAMPP=C:\xampp"
set "APP=%XAMPP%\htdocs\printshop"
set "MYSQL=%XAMPP%\mysql\bin\mysql.exe"
set "KEYDIR=%XAMPP%\printshop-key"
set "KEY=%KEYDIR%\id_printshop"
set "GITDIR=%ProgramFiles%\Git"
if defined ProgramW6432 set "GITDIR=%ProgramW6432%\Git"
set "GIT=%GITDIR%\cmd\git.exe"
set "LOG=%TEMP%\printshop-setup.log"

rem Port 443 (not 22): SSH on port 22 to GitHub is often cut ("Connection reset").
set "REPO=ssh://git@ssh.github.com:443/Alipishdad99/printshop-release.git"
set "GIT_SSH_COMMAND=ssh -i C:/xampp/printshop-key/id_printshop -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=C:/xampp/printshop-key/known_hosts -o ConnectTimeout=30 -o ServerAliveInterval=15"

rem ---------- 64-bit or 32-bit Windows ----------
rem (a 32-bit cmd on 64-bit Windows reports x86 but sets PROCESSOR_ARCHITEW6432)
set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 set "ARCH=x86"
set "MIRROR=https://github.com/Alipishdad99/printshop-guide/releases/download/installers-1"
if "%ARCH%"=="x86" goto :arch_x86
rem 64-bit: official XAMPP portable (no installer). SourceForge blocks Iran, so the
rem official zip is mirrored on GitHub; SourceForge stays as the second source.
set "VCNAME=VC_redist.x64.exe"
set "URL_VC=https://aka.ms/vs/16/release/vc_redist.x64.exe"
set "XZIP=xampp-portable-windows-x64-7.4.33-0-VC15.zip"
set "URL_XAMPP=%MIRROR%/xampp-portable-windows-x64-7.4.33-0-VC15.zip"
set "URL_XAMPP2=https://downloads.sourceforge.net/project/xampp/XAMPP%%20Windows/7.4.33/xampp-portable-windows-x64-7.4.33-0-VC15.zip"
set "GITNAME=Git-2.46.2-64-bit.exe"
goto :arch_done
:arch_x86
rem 32-bit: XAMPP 7.4 has no 32-bit build, so the same layout is made from the official
rem 32-bit Apache 2.4.57 (Apache Lounge), PHP 7.4.33 (php.net) and MariaDB 10.4.22 (mariadb.org)
set "VCNAME=VC_redist.x86.exe"
set "URL_VC=https://aka.ms/vs/16/release/vc_redist.x86.exe"
set "XZIP=printshop-xampp-x86-7.4.33.zip"
set "URL_XAMPP=%MIRROR%/printshop-xampp-x86-7.4.33.zip"
set "URL_XAMPP2="
set "GITNAME=Git-2.46.2-32-bit.exe"
:arch_done
set "URL_GIT=https://github.com/git-for-windows/git/releases/download/v2.46.2.windows.1/%GITNAME%"

echo.
echo  ==============================================================
echo    Printshop setup
echo    Do not close this window. Some steps take several minutes.
echo  ==============================================================
echo.

echo    Windows: %ARCH%
echo.

rem ================= 1. Visual C++ =================
echo [1/7] Visual C++ runtime
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\%ARCH%" /v Installed >nul 2>&1 && goto :vc_ok
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\%ARCH%" /v Installed >nul 2>&1 && goto :vc_ok
set "DURL=%URL_VC%"
set "DNAME=%VCNAME%"
call :download
if errorlevel 1 goto :fail
echo       Installing, 1-2 minutes...
"%HERE%\%VCNAME%" /install /quiet /norestart
set RC=%errorlevel%
rem 0 = done, 1638 = a newer one is already installed, 3010 = done (restart later)
if not "%RC%"=="0" if not "%RC%"=="1638" if not "%RC%"=="3010" (
  echo [X] Visual C++ install failed, code %RC%. Restart Windows and run setup again.
  goto :fail
)
:vc_ok
echo       OK

rem ================= 2. XAMPP =================
echo [2/7] XAMPP 7.4 in %XAMPP%
if exist "%XAMPP%\php\php.exe" goto :xampp_have
rem a half-finished XAMPP folder (e.g. from a failed installer) is kept aside, not deleted
if exist "%XAMPP%" (
  echo       Found an incomplete %XAMPP% - moving it to %XAMPP%.old-%RANDOM%
  move "%XAMPP%" "%XAMPP%.old-%RANDOM%" >nul
  if exist "%XAMPP%" (
    echo [X] Cannot move the old %XAMPP% folder. Close programs using it, or restart Windows, and run setup again.
    goto :fail
  )
)
set "DURL=%URL_XAMPP%"
set "DURL2=%URL_XAMPP2%"
set "DNAME=%XZIP%"
call :download
if errorlevel 1 goto :fail
echo       Extracting XAMPP into %XAMPP%, 2-15 minutes. Please wait...
set "UZIP=%HERE%\%XZIP%"
set "UDEST=%XAMPP%\.."
set "UCHECK=%XAMPP%\php\php.exe"
call :unzip
if errorlevel 1 (
  echo [X] Could not extract XAMPP. The zip may be damaged: delete %XZIP% from this folder and run setup again.
  goto :fail
)
:xampp_have
rem (not with for /f: cmd drops the ; and PHP gets broken code; -n: no php.ini, so no warnings)
set PHPV=
"%XAMPP%\php\php.exe" -n -r "echo PHP_MAJOR_VERSION, PHP_MINOR_VERSION;" > "%TEMP%\printshop-phpv.txt" 2>nul
set /p PHPV=<"%TEMP%\printshop-phpv.txt"
if not "%PHPV%"=="74" (
  echo [X] %XAMPP% has PHP %PHPV%, but the program needs XAMPP 7.4.
  echo     Uninstall that XAMPP, or rename the folder, and run setup again.
  goto :fail
)
echo       OK

rem ================= 3. Services =================
echo [3/7] Apache and MySQL - start automatically with Windows
sc query mysql >nul 2>&1
if errorlevel 1 "%XAMPP%\mysql\bin\mysqld.exe" --install mysql --defaults-file="%XAMPP%\mysql\bin\my.ini" >>"%LOG%" 2>&1
sc config mysql start= auto >nul 2>&1
net start mysql >nul 2>&1
call :wait_mysql
if errorlevel 1 (
  echo [X] MySQL does not start. Maybe another MySQL is installed on this computer.
  echo     Details: %LOG%
  goto :fail
)
sc query Apache2.4 >nul 2>&1
if errorlevel 1 "%XAMPP%\apache\bin\httpd.exe" -k install -n "Apache2.4" >>"%LOG%" 2>&1
sc config Apache2.4 start= auto >nul 2>&1
net start Apache2.4 >nul 2>&1
set APACHE_OK=
sc query Apache2.4 | findstr /c:"RUNNING" >nul && set APACHE_OK=1
if not defined APACHE_OK (
  echo [!] Apache did not start. Another program is probably using port 80
  echo     - for example Skype, IIS or another web server. Close it; setup goes on.
)
echo       OK

rem ================= offline: program zip next to this file? =================
rem (printshop-vX.Y.Z.zip from the seller, e.g. on a USB stick)
set ZIPF=
if not exist "%APP%\install.bat" for %%z in ("%HERE%\printshop-v*.zip") do set "ZIPF=%%~fz"
if not defined ZIPF goto :zip_done
echo       Extracting %ZIPF% ...
set "UZIP=%ZIPF%"
set "UDEST=%XAMPP%\htdocs"
set "UCHECK=%APP%\install.bat"
call :unzip
if errorlevel 1 (
  echo [X] Could not extract the zip. Extract it by hand into %XAMPP%\htdocs and run setup again.
  goto :fail
)
:zip_done

rem ================= program files already here? =================
rem (zip extracted above, or by hand into htdocs)
if exist "%APP%\install.bat" if not exist "%APP%\.git" (
  echo [4/7] Program files are already in %APP% - Git not needed.
  echo [5/7] Skipped.
  echo [6/7] Skipped.
  goto :install
)

rem ================= 4. Git =================
echo [4/7] Git
if exist "%GIT%" goto :git_ok
set "DURL=%URL_GIT%"
set "DNAME=%GITNAME%"
call :download
if errorlevel 1 goto :fail
echo       Installing, 1-3 minutes...
"%HERE%\%DNAME%" /VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES
if not exist "%GIT%" (
  echo [X] Git was not installed. Run setup again.
  goto :fail
)
:git_ok
rem setup runs as Administrator, update.bat later runs as the normal user
"%GIT%" config --system --get-all safe.directory 2>nul | findstr /i /c:"C:/xampp/htdocs/printshop" >nul || "%GIT%" config --system --add safe.directory C:/xampp/htdocs/printshop
echo       OK

rem ================= 5. Access key =================
echo [5/7] Access key of this computer
if not exist "%KEYDIR%" mkdir "%KEYDIR%"
if not exist "%KEY%" "%GITDIR%\usr\bin\ssh-keygen.exe" -q -t ed25519 -C "printshop-%COMPUTERNAME%" -f C:/xampp/printshop-key/id_printshop -N ""
if not exist "%KEY%.pub" (
  echo [X] Could not create the key.
  goto :fail
)
call :check_access
if "%ACCESS%"=="ok" goto :access_ok

copy /y "%KEY%.pub" "%USERPROFILE%\Desktop\printshop-key.txt" >nul 2>&1
clip < "%KEY%.pub"
echo.
echo  ==============================================================
echo    This computer needs permission to download the program.
echo.
echo    Send the line below to the seller - Telegram or Bale:
echo      Ali Pishdad - 09046047852 - Telegram @alipishdad313 - Bale @alipishdad99
echo.
echo    It is ALREADY COPIED: just open the chat and Paste (Ctrl+V).
echo    It is also saved on the Desktop as printshop-key.txt
echo  ==============================================================
echo.
type "%KEY%.pub"
echo.
echo  Waiting for the seller to approve. Checking every 20 seconds...
echo  Leave this window open; setup continues by itself.
:wait_access
timeout /t 20 /nobreak >nul
call :check_access
if "%ACCESS%"=="ok" goto :access_ok
if "%ACCESS%"=="net" (
  echo    ...internet problem, trying again: & type "%LOG%.git" 2>nul
) else (
  echo    ...not approved yet
)
goto :wait_access
:access_ok
echo       Approved - OK

rem ================= 6. Download the program =================
echo [6/7] Downloading the program
if exist "%APP%\.git" (
  "%GIT%" -C "%APP%" pull --ff-only
  if errorlevel 1 echo [!] Could not update the existing copy; going on with it.
  goto :git_config
)
if exist "%APP%" (
  rem a left-over folder: keep it aside instead of deleting anything
  move "%APP%" "%APP%.old-%RANDOM%" >nul
)
set /a TRY=0
:clone
set /a TRY+=1
"%GIT%" clone "%REPO%" "%APP%"
if not errorlevel 1 goto :git_config
if exist "%APP%" rmdir /s /q "%APP%"
if %TRY% lss 5 (
  echo    Internet problem - trying again in 15 seconds, try %TRY% of 5...
  timeout /t 15 /nobreak >nul
  goto :clone
)
echo [X] Download failed 5 times. Check the internet and run setup again.
goto :fail
:git_config
rem updates (update.bat) use the same key and port 443
"%GIT%" -C "%APP%" config core.sshCommand "%GIT_SSH_COMMAND%"
"%GIT%" -C "%APP%" remote set-url origin "%REPO%"
echo       OK

rem ================= 7. Install =================
:install
echo [7/7] Installing the program
call "%APP%\install.bat" /auto
if errorlevel 1 goto :fail

echo.
echo  ==============================================================
echo    Setup finished.
echo    This computer:    http://localhost
echo    Other computers:  http://THIS-COMPUTER-IP   (see ipconfig)
echo    Apache and MySQL start by themselves with Windows.
echo    Updates later: double-click update.bat in %APP%
echo  ==============================================================
start "" http://localhost
pause
exit /b 0

rem ====================================================================
rem  helpers
rem ====================================================================

rem Download %DURL% as %HERE%\%DNAME% (kept, so a second run does not download again).
rem Tries curl, PowerShell and BITS; if all fail, opens the browser for a manual download.
:download
if exist "%HERE%\%DNAME%" (
  echo       Using %DNAME% from this folder.
  set "DURL2="
  exit /b 0
)
echo       Downloading %DNAME% ...
set "DPART=%HERE%\%DNAME%.part"
:dl_retry
if exist "%DPART%" del /f /q "%DPART%"
if not exist "%SystemRoot%\System32\curl.exe" goto :dl_ps
"%SystemRoot%\System32\curl.exe" -L --fail --retry 3 --connect-timeout 30 -o "%DPART%" "%DURL%"
if not errorlevel 1 goto :dl_done
:dl_ps
if exist "%DPART%" del /f /q "%DPART%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{[Net.ServicePointManager]::SecurityProtocol=3072}catch{}; (New-Object Net.WebClient).DownloadFile('%DURL%','%DPART%')" >nul 2>&1
if not errorlevel 1 if exist "%DPART%" goto :dl_done
if exist "%DPART%" del /f /q "%DPART%"
bitsadmin /transfer printshop /download /priority foreground "%DURL%" "%DPART%" >nul 2>&1
if not errorlevel 1 if exist "%DPART%" goto :dl_done
if exist "%DPART%" del /f /q "%DPART%"
rem second source (if any), once
if defined DURL2 (
  set "DURL=%DURL2%"
  set "DURL2="
  goto :dl_retry
)
echo.
echo  [!] Automatic download did not work.
echo      The browser opens now. Save the file into this folder:
echo        %HERE%
echo      File name: %DNAME%
start "" "%DURL%"
:dl_wait
echo      When the download has finished, press a key here.
pause >nul
if exist "%HERE%\%DNAME%" exit /b 0
echo      Not found yet: %HERE%\%DNAME%
goto :dl_wait
:dl_done
move /y "%DPART%" "%HERE%\%DNAME%" >nul
set "DURL2="
exit /b 0

rem Extract %UZIP% into %UDEST%; success when %UCHECK% exists.
rem Windows 10/11: tar. Windows 7: Windows' own zip support (shows a progress window);
rem it copies in the background, so wait until nothing has changed for 30 seconds.
:unzip
rem Windows own tar by full path (Git has another tar that misreads C:)
if exist "%SystemRoot%\System32\tar.exe" "%SystemRoot%\System32\tar.exe" -xf "%UZIP%" -C "%UDEST%"
if exist "%UCHECK%" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "$z='%UZIP%'; $d=(Resolve-Path '%UDEST%').Path; $sh=New-Object -ComObject Shell.Application; $sh.NameSpace($d).CopyHere($sh.NameSpace($z).Items(),16); $top=Join-Path $d ($sh.NameSpace($z).Items() | Select-Object -First 1).Name; $p=''; $same=0; while($same -lt 15){Start-Sleep 2; $f=Get-ChildItem $top -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {-not $_.PSIsContainer} | Measure-Object -Property Length -Sum; $k=[string]$f.Count+'/'+[string]$f.Sum; if($f.Count -gt 0 -and $k -eq $p){$same++}else{$same=0}; $p=$k}"
if exist "%UCHECK%" exit /b 0
exit /b 1

rem Wait up to 60 s until MySQL answers.
:wait_mysql
set /a N=0
:wm_loop
"%MYSQL%" -u root -e "SELECT 1" >nul 2>&1 && exit /b 0
set /a N+=1
if %N% geq 30 exit /b 1
timeout /t 2 /nobreak >nul
goto :wm_loop

rem Sets ACCESS=ok, denied (key not approved yet) or net (internet problem).
:check_access
"%GIT%" ls-remote "%REPO%" HEAD >"%LOG%.git" 2>&1
if not errorlevel 1 (
  set ACCESS=ok
  exit /b 0
)
findstr /i /c:"denied" "%LOG%.git" >nul
if not errorlevel 1 (
  set ACCESS=denied
) else (
  set ACCESS=net
)
exit /b 0

:fail
echo.
echo  === Setup stopped. Fix the problem above and run setup again;
echo      finished steps are skipped.
echo      Support: Ali Pishdad - 09046047852 (phone) - Telegram: @alipishdad313 - Bale: @alipishdad99
pause
exit /b 1
