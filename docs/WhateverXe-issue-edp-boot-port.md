# [Twin Lake N150 0x46D4][Tahoe 26.7.3] Internal eDP laptop: no acceleration on 0.8.2 — `N97FramebufferStartAccepted = No`, accelerator `start()` returns false (eDP boot-port mode-0 admission missing from 0.8.2)

### Pre-submission check

- [x] macOS was installed and booted with neither WhateverXe nor WhateverXe Graphics active (`-wexoff`); WEX was enabled afterwards.

### Summary

On an ASUS ExpertBook BR1104FTA (Intel N150, iGPU `8086:46D4` rev `0x00`, 24 EU, **internal eDP** 1366x768), WhateverXe 0.8.2 RELEASE loads and every admission/preflight gate reports green. The Apple TGL framebuffer and accelerator kexts load from the AuxKC, and `IntelAccelerator::probe()` succeeds. But the native framebuffer controller start is **not accepted** (`N97FramebufferStartAccepted = No`) and the accelerator `start()` returns false. No `IntelAccelerator` / `IGAccel*` object is published, and the system stays on the 4 MB firmware framebuffer with the placeholder `IOAccelerator` (`com.unknown.bundle`, `AGXMetalA12`).

The state matches #112 (ALLDOCUBE GTBook14, ADL-N `46D2`, internal eDP, 0.8.2) and the display-side part of #114 and #100. In #112 the reporter confirms that commit `9c219ee` ("Admit the eDP boot port with native mode 0 at the firmware handoff") fixes it. That commit is on a branch that diverged before 0.8.2 (`compare 0.8.2...9c219ee`: diverged, ahead 1, behind 58). **The 0.8.2 RELEASE binary does not contain it.** The symbol `XE::display13PanelBootPort` and the log string `Display13 eDP boot port on DDI %u admitted with native mode 0` are both absent from the release binary (details below).

Request: please merge the mode-0 eDP boot-port admission (or an equivalent) into a release. I can test a CI or DEBUG build on this machine.

---

### Environment

| Item | Value |
| --- | --- |
| Computer | ASUS ExpertBook BR1104FTA (laptop) |
| CPU | Intel N150 (Twin Lake) |
| iGPU | `8086:46D4`, revision `0x00`, subsystem `1043:3FD8`, ACPI `\_SB.PC00.GFX0` (IOReg `IGPU@2`) |
| GT / display | `N97GTStep = "A0"`, `N97DisplayVersion = 13`, `N97DisplayStep = "D0"`, 24 EU (from `N97GTReadout`) |
| Display | Internal eDP only, 1366x768, 24-bit. No external display connected |
| macOS | 26.7.3 (25G342), Darwin 25.6.0 `xnu-12377.161.15.701.48~2/RELEASE_X86_64` |
| OpenCore | RELEASE build |
| WhateverXe | **0.8.2 RELEASE**. Binary SHA-256 `d4e958a3d5047e998538d1d53cb5e3e58d775abed21d42556b9051f102d867e0`, identical to the official `WhateverXe-0.8.2-RELEASE.zip` (zip SHA-256 `6c004bdfd9c6ce369dcb4dde515fc16e893345061dc63eb0302634ad7d8525b8`, matches `SHA256SUMS`) |
| WhateverXe Graphics | Standard pkg from the releases page. First installed 2026-11-13, reinstalled 2026-11-14 (latest release at that time: 0.4.4). The loaded `org.b00t0x.AppleIntelTGLCompat` reports **0.8.1** in `kmutil`; its log line says `revision 0.5.0` |
| AMFIPass | 1.4.1 **Mod** from `WhateverXe-Graphics/extras`. Binary SHA-256 `2d36aeca1740b258e6bb0b66844b5bfb59a0edb7cdd9ef78206689e5d223d8dc`, identical to the Mod zip |
| Lilu | 1.7.3 |
| WhateverGreen | Not present |
| csr-active-config | `030A0000` (`0xA03`). The README recommends `0x803`; this value has the extra `CSR_ALLOW_UNAPPROVED_KEXTS (0x200)` bit. Kexts and the AuxKC load normally. I can retest with `0x803` if it matters |
| boot-args | `-v debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt -vi2c-force-polling` |
| DeviceProperties `PciRoot(0x0)/Pci(0x2,0x0)` | `framebuffer-patch-enable = 01000000`, `framebuffer-stolenmem = 0000C003` |
| BIOS DVMT | Fixed by firmware, not adjustable (see the GGC decode below) |

Other loaded third-party kexts: AMFIPass Mod, ForgedInvariant 1.5.0, RestrictEvents 1.1.7, VirtualSMC 1.3.9, USBToolBox 1.2.0 + UTBDefault, RealtekRTL8111 2.4.2, VoodooPS2 2.3.8, VoodooI2C 2.9.1. No other graphics-related kexts.

### Symptom

- `system_profiler SPDisplaysDataType`: `VRAM (Total): 4 MB`, `Kernel Extension Info: No Kext Loaded`, Device ID `0x46d4`, display online at 1366x768.
- No `IntelAccelerator` / `IGAccel*` class in the registry (`ioreg -l -w0 | grep -c -E 'class (IntelAccelerator|IGAccel)'` = `0`).
- Placeholder accelerator present (same as #114):
  ```
  IOAccelerator <class IOServiceCompatibility>
  {"IOName"="IOAccelerator","CFBundleIdentifier"="com.unknown.bundle","IOClass"="IOAccelerator",
   "PerformanceStatistics"={"vramFreeBytes"=15728640},"IOGLBundleName"="AppleMetalGLRenderer",
   "MetalPluginName"="AGXMetalA12","VRAM,totalMB"=16384}
  ```
- `AppleIntelFramebuffer@0/@1/@2` exist under `IGPU@2` with `WEXFramebufferManagersBound = Yes` and `N97FBManagersBound = Yes`. `.Display_boot` (`IONDRVFramebuffer`) is the active boot display. No panic and no hang; the UI runs on software rendering.
- Reinstalling the Graphics pkg (AuxKC rebuilt by `kmutil` at runtime, then a reboot) changes nothing.

### Loaded graphics stack (`kmutil showloaded`)

```
 61  org.b00t0x.WhateverXe (0.8.2)                               0xffffff800445d000  size 0x910000
122  org.b00t0x.AppleIntelTGLCompat (0.8.1)                      0xffffff7f96d26000  size 0x24b4
123  com.apple.driver.AppleIntelTGLGraphicsFramebuffer (16.0.0)  0xffffff7f96e76000  size 0xc8000
136  com.apple.driver.AppleIntelTGLGraphics (16.0.0)             0xffffff7f96d2a000  size 0xc7ff9
119  com.apple.iokit.IOGraphicsFamily (600)
121  com.apple.iokit.IOAcceleratorFamily2 (487.4.4)
```

`/Library/GPUBundles`: `AppleIntelTGLGraphicsGLDriver.bundle`, `AppleIntelTGLGraphicsMTLDriver.bundle`, `AppleIntelTGLGraphicsVADriver.bundle`, `XeCompilerAdapter.bundle`, `XeOpenCL`.

AuxKC log: `AuxKC bundle com.apple.driver.AppleIntelTGLGraphicsFramebuffer / org.b00t0x.AppleIntelTGLCompat / com.apple.driver.AppleIntelTGLGraphics marked as loadable`.

### Kernel log

Complete output for these senders, from `log show --last boot --info --debug`:

```
20:51:05.718 (AppleIntelTGLCompat) AppleIntelTGLCompat: revision 0.5.0 started, physical-owner/binding selection
20:51:05.749 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Remove this when no loner needed (nvram values persist)
20:51:05.749 (AppleIntelTGLGraphics) [IGPU] virtual IOService *IntelAccelerator::probe(IOService *, SInt32 *): Found device with ID 0x46d48086, revision 0x0, PCH id 0x0, PCH rev 0x0 at PCI 0:2:0
20:51:05.749 (AppleIntelTGLGraphics) [IGPU] (same line repeated)
20:51:05.848 (AppleIntelTGLGraphicsFramebuffer) [IGFB][INFO ][DISPLAY  ] Starting FB driver
20:51:05.848 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Remove this when no loner needed (nvram values persist)
20:51:05.857 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Remove this when no loner needed (nvram values persist)
20:51:05.858 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] This should not be needed if we get right timing from AGDC for DSC display
20:51:05.858 (AppleIntelTGLGraphicsFramebuffer) [IGFB][ERROR][DISPLAY  ] EFI using a different backlight frequency
20:51:05.865 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Remove if not needed
20:51:05.874 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Remove this when no loner needed (nvram values persist)
20:51:05.874 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] GT4?
20:51:05.874 (AppleIntelTGLGraphicsFramebuffer) [IGFB][WARN ][BRINGUP  ] Do we need to update video freq request?
20:51:05.876 (AppleIntelTGLGraphics) [IGPU] Detecting Pre-Si/Si Mode ... [Si]
20:51:05.876 (AppleIntelTGLGraphics) [IGPU] Detecting Pre-Si/Si Mode ... [Si]
-- nothing further from AppleIntelTGLGraphics / WhateverXe / IOAccelerator for the rest of the boot --
20:51:23.094 (AppleGraphicsPowerManagement) [AGPM] ... GPU = IGPU Initialized, Control ID 16
```

No WhateverXe `SYSLOG` line appears in the unified log on this RELEASE build. For example `TGL accelerator start entered`, `AlderLakeN native RCS profile qualification rejected accelerator start` and `Display13 native controller start return=%u` are not printed. I can rerun with the DEBUG build and `-wexdbg -liludbgall` if you want the full trace.

---

### Admission and state keys (`IGPU@2` and registry root)

Green:

```
N97BringupVersion                   = 1
N97Admission                        = Yes
N97NativePreflight                  = Yes
N97NativeStartAllowed               = Yes
N97NativeKernelReady                = Yes
N97NativeReservedGGTT               = Yes
N97NativeRCSProfileReady            = Yes
N97GTTopologyReady                  = Yes
N97FramebufferOriginalStart         = Yes
N97FramebufferBackendReady          = Yes
N97FBSharedProbeAvailable           = Yes    N97FBSharedProbeBound = Yes
XELPSharedProbeAvailable            = Yes    XELPSharedProbeBound  = Yes
WEXDisplay13BootReady               = Yes
N97DisplayReadoutStatus             = 1
N97NativeEDRAM                      = 0
TGLAcceleratorAdmissionReady        = Yes
TGLAcceleratorSKUPatch              = Yes
TGLWEGAcceleratorStartRouted        = Yes
TGLWEGAcceleratorObservationsRouted = Yes
TGLPcodeAcceleratorReady            = Yes
TGLSonomaSurfaceAcceleratorReady    = Yes
(every N97FB*HooksReady and WEXDisplay13*Ready key = Yes)
```

Not green, or otherwise relevant:

```
N97FramebufferStartAccepted       = No     <-- controller start not accepted
N97ContextPublishReady            = No
N97KernelContextTrialReady        = No
N97SharedRegisterPrerequisites    = No
TGLTahoeDisabledTrials            = 31     (0x1F: five trial paths disabled on Tahoe)
TGLRPCSFullSliceReady             = No
TGLSubmitHistoryReady             = No
TGLSameTailRestoreReady           = No
TGLContextCacheIndirectReady      = No
TGLGSYNCDisableReady              = No
TGLCompletionConstAlternativeReady / Requested = No / No
TGLHostSubmitCount = 0   TGLHostWaitCount = 0   TGLHostLoadCount = 0   TGLHostMapCount = 0   TGLHostCSBCount = 0
TGLHostIRQCount0..2 = 0  TGLFBIRQCount0..6 = 0
```

Keys that the 0.8.2 binary defines but that are **absent** from this registry, so those code paths never ran:

`N97GPULease`, `N97GPUCommandTest`, `N97GGTTLease`, `N97GGTTReadout`, `N97ScanoutTest`, `N97ScanoutAllocation`, `N97NativePreEngineReady`, `N97NativeProbeBlocked`, `N97RejectedAcceleratorGuardReady`, `N97LoadOnly*`, `N97ParentStart{Entered,Result,Returned}`, `N97NativeConfigure{Entered,Result,Returned}`, `N97ConfigureDeviceEntered`, `N97MemoryStage{Entered,Returned}`, `N97MemoryConfigure*`, `N97EventInit*`, `N97DisplayInit{Entered,Returned}`, `N97KernelTaskBoundaryEntered`, `N97FBGTTInit`, `N97FBScanoutSetup`, `N97FBScanoutSwap`, `N97FBStolenHandoff`, `N97FBBacking`, `N97FBBinding`, `N97FBIRQ`, `N97FBEngineStop*`, `N97FBPortProbe*`, `N97FBPortDDC*`, `N97FBEDID*`, `N97Display13Linear`, `N97Display13After`, `N97DualGOP*`, `N97FixedSysMem{Request,Rejected}`, `N97SharedFramebuffer`.

So none of the native parent, memory, event or display stages after the framebuffer start were entered, and no fixed-sysmem request was made.

### Decoded blobs

All values are little-endian. The field meanings are my reading of the key names and of #100 / #114; please correct me where they are wrong.

**Device selection and boot source**

```
WhateverXeDeviceSelection   = <01000000 8680d446 00000000 8680d446 02000000 0d000000 03000000 01000000>
                              valid=1, physical=0x46D48086, override=0, selected=0x46D48086, 2, display=13, 3, 1
N97PhysicalIdentity         = 1188331654 (0x46D48086)    N97PhysicalRevision = 0
N97NativeBootSource         = u32 {1, bootDDI=0, protocol=2, planStatus=1, tc=0}   (firmware eDP on Combo DDI A, accepted)
N97NativeBootConnector      = u32 {1, 0, 1, 0, 0, 0, 1, 0, 16, 0, 0, 0}
WEXDisplay13BootHandoff     = u32 {1, 2, 0, 10, 3006, 3012, 0}
WEXDisplay13ClientReadiness = u32 {1,0, 1,0, 0,0, 1,0, 1,0, 2,0}
WhateverXeFirmwarePanel     = u32 {1, 2, 0, 0, 0}
WhateverXeFirmwarePorts     = u32 {1, 1, 2, 0xFB, 0x19, 0, 9, 1, 0, 0, 0, 0}
WEXDisplay13TCBootPorts     = u32 {1, 3, 4, 128, 0, 0, 0x01E07801, 3,  3, 4, 4, 128, 0, 0, 0x01E07801, 3,  3, 0, ...}
WEXDisplay13UnusedTC        = u32 {1, 1, 0, 0, 4, 128, 0, 0, 0, 0}
```

The boot source is identical to the working 46A3 machine in #114 (`{1, bootDDI=0, protocol=2, planStatus=1, tc=0}`). So the firmware source itself is accepted, and the failure happens later, at the controller start / boot-port admission.

**GT readout** (`N97GTReadout`, 240 bytes, u32)

```
1 6 4 3 3 0 0x10000 0 0 0 1 1 0x10000 0x10000 0 0 1 3 0x88 0xF0 0x000E00FE 1 2 4 24 4 0x100 0x10
then register / value pairs:
0x2030 0x2034 0x2038 0x203C 0x209C(=0x200) 0x2234(=1) 0x2238 0x229C
0x22030 0x22034 0x22038 0x2203C 0x2209C(=0x200) 0x22234(=1) 0x22238 0x2229C
```

`EU = 24`, `banks = 4` (indices 24 and 25, if I read the struct right). The third dword is `4`, the same value #114 discusses as the video-engine mask. Here `N97GTTopologyReady = Yes`, so the GT gate passes on ADL-N.

**Memory layout, stolen memory, GGTT**

```
GGC (N97GGC / WhateverXePhysicalGGC) = 705 = 0x02C1
    GGCLCK=1, IVD=0, GGMS=3 (8 MB GSM), GMS=0x02 (64 MB DSM)
IODeviceMemory BAR0 (GTTMMADR) = 0x40_1100_0000, length 0x0100_0000 (16 MB)
IODeviceMemory BAR2 (GMADR)    = 0x40_0000_0000, length 0x1000_0000 (256 MB aperture)
N97PhysicalMemoryLayout  = u64 {1, 1, 0x7C800000, 0x04000000, 0x00800000, 0x10000000}
                           valid, ?, DSM base 0x7C800000, DSM 64 MB, GSM 8 MB, aperture 256 MB
N97StolenReservation     = u64 {1, 1, 0x80600087, 0x03E00000}   (62 MB reserved)
framebuffer-stolenmem    = 0x03C00000 (60 MB, from DeviceProperties)
N97DVMTCalcPolicy        = u64 {1, 0x2C1, 0x04000000, 0x04000000, 0, 0, 0, 1}
N97DisplayPoolPolicy     = u64 {2, 0x04000000, 0x03C00000, 0x04000000, 0x03E00000, 0x03C00000, 1, 0x04000000}
N97FBMemory              = u64 {0x100000001, 1, 0x03C0000000000000, 0x3C00, 0x7C800000, 0, 0x9400000800000000, 0x02FF055500000056, 0x3C00}
N97FBGTTAdmission        = u64 {1, 0, 0, 1, 0x4011000000, 0x4011000000, 0x01000000, 0x01000000, 0x4011000000, 0x4011000000, 1}
N97NativeMapperAdmission = u64 {1, 0, 0, 1}
N97FixedSysMemEnabled    = Yes   (no N97FixedSysMemRequest recorded)
N97NativeGGTTSystemFlagsReady = Yes    N97NativeGOPPTEPreservation = Yes
TGLGGTT64Writes          = Yes
```

**MMIO mapping**

```
TGLTahoeMMIOGuard      = u64 {1, 1, 0x4011000000, 0x01000000, 0x0001040600070406, 1,1,1,1,1,1,1,1,1,1,1, 0, 1, 0xffffff9690106600, 1}
TGLMMIOMappingEvidence = tag 0x72; phys 0x4011000000, length 0x1000000, mapped at 0xffffff8024db0000;
                         page entries 0x4011002510 / 0x4011190030 / 0x4011fff000, PTE flags 0x8040004011xxx01b (UC)
TGLMMIOCacheUpdate     = u64 {0x73, 0xffffff8024db0000, 1, 0, 2, 3, 1, 0x1000}
TGLMMIOStrongUCPreflight = Yes    TGLMMIOStrongUCRouted = Yes
```

**Framebuffer power and resource records**

```
N97FBBootHandoff        = u32 {1,0, 2,0, 7,0, 0,0, 1,0, 0x13,0, 0,0, 1,0, 1,0, 1,0, 0,0, 0x19F,0, 0,0, 0,0, 4,0, ...}
N97FBFirstPowerError    = identical to N97FBBootHandoff (the first power error is recorded at the handoff)
N97FBPower              = u64 {1, 1, 0, 0, 0, 0x13, 0, 0, 1, 0, 0, 0x19F, 0, 0, 3, 0, 1, ...}
N97FBBootHandoffCheck   = u32 {3,0, 1,0, 1,0, 1,0, 1,0, 1,0, 1,0, 1,0, 1,0, 1,0, 0,0, 0,0, 0,0, 1,0, 1,0, 1,0, 0,0, 0,0, 1,0, 1,0, ...}
N97FBFirstResourceFault = u64 {1, 0x218B, 0xFFFFFFFF, 1, 0x4549AD76D (timestamp), 0, ..., 1, 0, 3, ..., 0x19F, ...}
N97FBEngine             = u64 {1,1,1,1, 0x155CC000, 1, 0, 0x1C000700, 0, 3, 0xF, 0xF, 0, 0, 0x800, 0, 0,
                               0xC040C000 x4, 0xC041C000 x4, 1, 1, 0, 9, ...}
N97FBScanoutAllocate    = u32 {2,0, 2,0, 1,0, 0,0, 0xFF,0, 0,0, 1,0, 0,0, 0,0, 1,0, 1,0, 0,0, 0,0, 5,0, 1,0}
N97FramebufferDualPolicy= u64 {1, 0x19, 1, 1, 1, 1, 1, 1, 1, 1}
N97GTFaultCapture       = header {3, 5, 0x18, 0x0E}, rest zero (1032 bytes)
N97RCSExecutionCapture  = header {6, 0x0A, 0x40, 0x2D}, rest zero (5232 bytes)
N97NativeSubmitCapture  = header {5, 0, 8, 0x27E00}, rest zero (1306720 bytes)
TGLIRQLive              = header {4}, rest zero (1012480 bytes)
TGLCSBModeAtInit        = {0x6B, 0xFFFFFFFF, ...}
```

### Accelerator trace (`TGLAccelFirst1..9` on the registry root; identical to `TGLAccelLast1..9`)

64-byte records, u64 fields. My reading of the layout: `{mach_absolute_time, context, seq, event, phase (0 = enter, 1 = return), provider, arg/result, aux}`.

```
#1 t=0x44CBBFE26 ctx=ffffffab5dc71a40 seq=1 ev=1 ph=0 prov=ffffffa692ff6000 arg=0x1              aux=0x46D48086
#2 t=0x44CBC73B3                      seq=2 ev=1 ph=1 prov=ffffffa692ff6000 arg=ffffffa692ff6000 aux=0x46D48086          probe returns the provider (success)
#3 t=0x454BC1F0F                      seq=3 ev=2 ph=0 prov=...              arg=0                aux=ffffffa1c339aec0  start enter
#4 t=0x454BC5300                      seq=4 ev=3 ph=0 prov=...              arg=0                aux=ffffff7fa794defd  (caller return address)
#5 t=0x454BC9C8C                      seq=5 ev=3 ph=1 prov=...              arg=0                aux=0
#6 t=0x454BCCF04                      seq=6 ev=4 ph=0 prov=...              arg=0                aux=0                 (no matching return record)
#7 t=0x454BCF52E                      seq=7 ev=3 ph=0 prov=...              arg=0x200            aux=ffffff7fa794e2a4  (caller return address)
#8 t=0x454BD20CD                      seq=8 ev=3 ph=1 prov=...              arg=0x200            aux=0
#9 t=0x454BD7A10                      seq=9 ev=2 ph=1 prov=...              arg=0                aux=ffffffa1c339aec0  start returns false
```

`prov = 0xffffffa692ff6000` is the `IGPU@2` `IOPCIDevice`. The accelerator `probe` succeeds. `start` enters, makes two nested event-3 calls from two different call sites and one event-4 call, and returns **0** shortly afterwards. Event 4 has no return record. If event 4 is `wrapTGLAcceleratorFailure(IOService*, unsigned)`, then the failure hook fired with code 0 inside `start`.

`TGLResource9First1/2` and `TGLResource10First1/2` are also recorded: same context `ffffffab5dc71a40`, resource IDs 9 and 10, object `ffffffb6d0188000`, callers `ffffff7fa7add64c` and `ffffff7fa7adda35`.

---

### Why I think this is the missing eDP boot-port admission

1. `N97FramebufferStartAccepted = No`, while `N97FramebufferOriginalStart = Yes` and every `N97FB*HooksReady` key is `Yes`. The native controller start ran but was not accepted.
2. That is exactly the state described in the commit message of `9c219ee`:
   > At the handoff a Combo eDP port still has native mode 0: Apple's setPortMode has not run yet, and display13SSTPort requires exactly 1. The boot port is rejected, adoptDPBootAUX and adoptBootPath are never reached, the handoff returns NotReady and the controller start is not accepted, so there is no accelerator (N97FramebufferStartAccepted = No).
3. This machine boots from the firmware eDP on **Combo DDI A** (`N97NativeBootSource` bootDDI=0, protocol=2). That is the case the fix admits (`config[0] < 2`, the panel bit from the VBT, port field `+0x550 == 0`).
4. The 0.8.2 RELEASE binary does not contain the fix:
   - Mach-O symbol table (971 symbols): `__ZN2XE16display13SSTPortEPv` at `0x5c340` and `__ZN2XE27wrapAlderLakeNSetupWorkLoopEP9IOServiceP10IOWorkLoop` at `0x35f20` are present. **`__ZN2XE22display13PanelBootPortEPv` is absent.**
   - `__TEXT,__cstring` (`0x112090`, size `0xd299`): the string `Display13 eDP boot port on DDI %u admitted with native mode 0` is **absent**.
   - GitHub `compare 0.8.2...9c219ee`: diverged, ahead 1, behind 58.
5. #112 (ADL-N `46D2`, internal eDP, 0.8.2 + Graphics 0.4.3, "7 MB, no Metal") reports that `9c219ee` alone fixes it. #114 (ADL-H `46A3`, 0.8.2) reached full acceleration with the `xps9720-igpu` contrib build, which carries the same admission (`renedis a57698f` / `nickk19 5b88080`).

### Relevant functions in the 0.8.2 RELEASE binary

Unslid addresses in `WhateverXe.kext/Contents/MacOS/WhateverXe` (`__TEXT,__text` starts at `0xe80`, size `0x111210`):

```
0x0110f0  XE::prepareDSIFirmware(IOService*)
0x011610  XE::adlnBootstrap(IOPCIDevice*)
0x01e850  XE::xelpBindProbe(void*)
0x01f320  XE::processKernel(KernelPatcher&, DeviceInfo*)
0x027790  XE::processKext(KernelPatcher&, unsigned long, unsigned long long, unsigned long)
0x028530  XE::processAlderLakeNRejectedAccelerator(KernelPatcher&, ...)
0x028710  XE::processAlderLakeNLoadOnly(KernelPatcher&, ...)
0x028d80  XE::processTGLAccelerator(KernelPatcher&, ...)
0x0305d0  XE::processDisplay13Framebuffer(KernelPatcher&, ...)
0x035f20  XE::wrapAlderLakeNSetupWorkLoop(IOService*, IOWorkLoop*)       <- boot-port admission site changed by 9c219ee
0x05c340  XE::display13SSTPort(void*)                                     <- requires native mode 1
0x0637d0  XE::prepareDisplay13BootScanout(IOPCIDevice*)
0x064f60  XE::wrapDisplay13FramebufferStart(IOService*, IOService*)       <- sets N97FramebufferStartAccepted
0x066f20  XE::adoptDSIBootPath(IOService*, OSObject*)
0x0840c0  XE::wrapAlderLakeNRejectedAcceleratorProbe(IOService*, IOService*, int*)
0x0841c0  XE::wrapTGLAcceleratorProbe(IOService*, IOService*, int*)
0x084510  XE::wrapTGLAcceleratorStart(IOService*, IOService*)             <- returns false (trace #9)
0x084fe0  XE::processAlderLakeNParentBoundary(KernelPatcher&, ...)
0x085480  XE::wrapAlderLakeNConfigureDevice(IOService*, IOPCIDevice*)    <- never entered (no N97ConfigureDeviceEntered)
0x085610  XE::processXELPMemoryStage(KernelPatcher&, ...)
0x085d90  XE::processAlderLakeNConfigStage(KernelPatcher&, ...)
0x0860f0  XE::processAlderLakeNEventStage(KernelPatcher&, ...)
0x0867a0  XE::processAlderLakeNTaskBoundary(KernelPatcher&, ...)
0x089500  XE::wrapTGLAcceleratorStop(IOService*, IOService*)
0x089560  XE::wrapTGLAcceleratorFailure(IOService*, unsigned int)
0x0895c0  XE::wrapTGLAcceleratorRegister(IOService*)
0x089b50  XE::wrapTGLAcceleratorStatusMemory(IOService*)
0x089ba0  XE::wrapTGLAcceleratorEngine(IOService*)
0x08a760  XE::wrapAlderLakeNNativeConfigure(IOService*, IOPCIDevice*)
0x08a8a0  XE::wrapAlderLakeNNativeGPUInfo(IOService*)
0x08a900  XE::wrapAlderLakeNNativeIRQ(IOService*)
0x08a960  XE::wrapTGLGuCLoadBinary(void*, bool)
0x092af0  XE::wrapFramebufferStart(IOService*, IOService*)
0x09a4f0  XE::wrapTGLFramebufferStart(IOService*, IOService*)
```

Kernel addresses seen in the trace, for symbolication on your side (KASLR slide unknown; `kmutil` lists `AppleIntelTGLGraphics` at `0xffffff7f96d2a000`, size `0xc7ff9`): `0xffffff7fa794defd`, `0xffffff7fa794e2a4`, `0xffffff7fa7add64c`, `0xffffff7fa7adda35`.

### Reproduction

1. ASUS BR1104FTA (N150, internal eDP), BIOS default DVMT (fixed 64 MB DSM).
2. OpenCore with Lilu 1.7.3, AMFIPass 1.4.1 Mod and WhateverXe 0.8.2 RELEASE (after Lilu); boot-args `-allow3d -disablegfxfirmware -igfxdvmt`; `framebuffer-patch-enable = 01000000`, `framebuffer-stolenmem = 0000C003`.
3. Boot Tahoe 26.7.3, install the WhateverXe Graphics pkg, reboot.
4. Result: 4 MB VRAM, `No Kext Loaded`, placeholder `IOAccelerator`, `N97FramebufferStartAccepted = No`.

### What I can test

- A 0.8.x build that contains `display13PanelBootPort`, or the CI artifact of the branch that carries it.
- The DEBUG build with `-wexdbg -liludbgall`, for a full trace.
- `csr-active-config = 0x803` instead of `0xA03`.

### Attachments

- `diag-20261114-204926.txt`: kextstat, `/Library/GPUBundles`, `IGPU@2` node, filtered kernel log, `SPDisplaysDataType`
- `diag-20261114-204926-ioreg.txt`: full `ioreg -l -w0` (6.3 MB)
- `diag2-20261114-205822.txt`: `log show --last boot --info --debug` for the AppleIntelTGL* / WhateverXe / IOAccelerator senders
