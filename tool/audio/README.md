# Audio build

The shipped StatOz WAV catalog is rebuilt with:

```powershell
python -m pip install numpy soundfile
python tool/audio/build_audio.py
python tool/audio/audit_audio.py
```

`build_audio.py` combines deterministic synthesis with selected transient
layers from Kenney's CC0 Interface Sounds and Impact Sounds packs. The source
archives are retained under `tool/audio/masters/kenney/`; none of that directory
is included by `pubspec.yaml`.

The build writes:

- `assets/audio/*.wav`
- `docs/audio/audio_manifest.yaml`
- `docs/audio/CUE_CATALOG.md`
- `final_over/assets/audio/*.wav`
- `final_over/docs/AUDIO_ASSET_MANIFEST.md`

Every shipped cue is mono, 44.1 kHz, PCM16 WAV. Do not hand-edit generated
files; update the cue spec or synthesis and rebuild. The audit rejects missing,
silent, clipped, malformed, duplicate-semantic, unmanifested, orphaned, or
poorly looping files and enforces the combined 15 MiB shipped-audio cap.
