from enum import Enum


class StylePreset(str, Enum):
    neutral = "neutral"
    lullaby = "lullaby"
    cinematic = "cinematic"
    ambient = "ambient"
    dark_low = "dark_low"


class ReverbLevel(str, Enum):
    none = "none"
    low = "low"
    medium = "medium"
    high = "high"


class VelocityStyle(str, Enum):
    even = "even"
    dynamic = "dynamic"
    soft = "soft"
    aggressive = "aggressive"


class ChordVoicing(str, Enum):
    block = "block"
    arpeggiated_up = "arpeggiated_up"
    arpeggiated_down = "arpeggiated_down"
    broken_slow = "broken_slow"
    sparse = "sparse"


class ChordComplexity(str, Enum):
    simple = "simple"
    extended = "extended"


class ChordProgressionPreset(str, Enum):
    cinematic_basic = "cinematic_basic"
    cinematic_suspense = "cinematic_suspense"
    descending = "descending"
    pedal_tonic = "pedal_tonic"
    pop_four = "pop_four"
    minimal = "minimal"


class Instrument(str, Enum):
    # Pianos
    ACOUSTIC_GRAND_PIANO = "acoustic_grand_piano"
    BRIGHT_ACOUSTIC_PIANO = "bright_acoustic_piano"
    ELECTRIC_GRAND_PIANO = "electric_grand_piano"
    HONKY_TONK_PIANO = "honky_tonk_piano"
    ELECTRIC_PIANO_1 = "electric_piano_1"
    ELECTRIC_PIANO_2 = "electric_piano_2"
    HARPSICHORD = "harpsichord"
    CLAVINET = "clavinet"

    # Chromatic Percussion
    CELESTA = "celesta"
    GLOCKENSPIEL = "glockenspiel"
    MUSIC_BOX = "music_box"
    VIBRAPHONE = "vibraphone"
    MARIMBA = "marimba"
    XYLOPHONE = "xylophone"
    TUBULAR_BELLS = "tubular_bells"
    DULCIMER = "dulcimer"

    # Guitars
    NYLON_ACOUSTIC_GUITAR = "nylon_acoustic_guitar"
    STEEL_ACOUSTIC_GUITAR = "steel_acoustic_guitar"
    JAZZ_ELECTRIC_GUITAR = "jazz_electric_guitar"
    CLEAN_ELECTRIC_GUITAR = "clean_electric_guitar"
    MUTED_ELECTRIC_GUITAR = "muted_electric_guitar"
    OVERDRIVEN_GUITAR = "overdriven_guitar"
    DISTORTION_GUITAR = "distortion_guitar"
    GUITAR_HARMONICS = "guitar_harmonics"

    # Bass
    ACOUSTIC_BASS = "acoustic_bass"
    FINGERED_ELECTRIC_BASS = "fingered_electric_bass"
    PICKED_ELECTRIC_BASS = "picked_electric_bass"
    FRETLESS_BASS = "fretless_bass"
    SLAP_BASS_1 = "slap_bass_1"
    SLAP_BASS_2 = "slap_bass_2"
    SYNTH_BASS_1 = "synth_bass_1"
    SYNTH_BASS_2 = "synth_bass_2"

    # Strings
    VIOLIN = "violin"
    VIOLA = "viola"
    CELLO = "cello"
    CONTRABASS = "contrabass"
    TREMOLO_STRINGS = "tremolo_strings"
    PIZZICATO_STRINGS = "pizzicato_strings"
    ORCHESTRAL_HARP = "orchestral_harp"
    TIMPANI = "timpani"
    STRING_ENSEMBLE_1 = "string_ensemble_1"
    STRING_ENSEMBLE_2 = "string_ensemble_2"
    SYNTH_STRINGS_1 = "synth_strings_1"
    SYNTH_STRINGS_2 = "synth_strings_2"

    # Choir - Sustained
    CHOIR_AAHS = "choir_aaahs"
    CHOIR_OOHS = "choir_ooohs"
    CHOIR_MMM_HUM = "choir_mmm_hum"
    CHOIR_LAHS_SUSTAIN = "choir_lahs_sustain"
    CHOIR_EEHS_SUSTAIN = "choir_eehs_sustain"
    CHOIR_WARM = "choir_warm"
    CHOIR_MYSTIC = "choir_mystic"

    # Choir - Staccato
    CHOIR_STACCATO_AH = "choir_staccato_ah"
    CHOIR_STACCATO_OOH = "choir_staccato_ooh"
    CHOIR_STACCATO_LAH = "choir_staccato_lah"
    CHOIR_STACCATO_POP = "choir_staccato_pop"

    # Choir - Children
    CHOIR_CHILDREN_AH = "choir_children_ah"
    CHOIR_CHILDREN_OOH = "choir_children_ooh"
    CHOIR_CHILDREN_HUM = "choir_children_hum"

    # Choir - Gendered
    CHOIR_FEMALE_AH = "choir_female_ah"
    CHOIR_FEMALE_OOH = "choir_female_ooh"
    CHOIR_MALE_AH = "choir_male_ah"
    CHOIR_MALE_OOH = "choir_male_ooh"
    CHOIR_MALE_LOW_DRONE = "choir_male_low_drone"

    # Vocal Effects
    VOCAL_BREATHY_PAD = "vocal_breathy_pad"
    VOCAL_WHISPER_HAIR = "vocal_whisper_hair"
    VOCAL_CHANT_LOW = "vocal_chant_low"
    VOCAL_CHANT_HIGH = "vocal_chant_high"
    VOCAL_OVERTONE_DRONE = "vocal_overtone_drone"
    VOCAL_THRILLER_SCREAM = "vocal_thriller_scream"
    VOCAL_VOCALISE = "vocal_vocalise"
    VOCAL_SIGHS = "vocal_sighs"

    # Brass
    TRUMPET = "trumpet"
    TROMBONE = "trombone"
    TUBA = "tuba"
    MUTED_TRUMPET = "muted_trumpet"
    FRENCH_HORN = "french_horn"
    BRASS_SECTION = "brass_section"
    SYNTH_BRASS_1 = "synth_brass_1"
    SYNTH_BRASS_2 = "synth_brass_2"

    # Reed
    SOPRANO_SAX = "soprano_sax"
    ALTO_SAX = "alto_sax"
    TENOR_SAX = "tenor_sax"
    BARITONE_SAX = "baritone_sax"
    OBOE = "oboe"
    ENGLISH_HORN = "english_horn"
    BASSOON = "bassoon"
    CLARINET = "clarinet"

    # Pipe
    PICCOLO = "piccolo"
    FLUTE = "flute"
    RECORDER = "recorder"
    PAN_FLUTE = "pan_flute"
    BLOWN_BOTTLE = "blown_bottle"
    SHAKUHACHI = "shakuhachi"
    WHISTLE = "whistle"
    OCARINA = "ocarina"

    # Synth Pads
    PAD_NEW_AGE = "pad_new_age"
    PAD_WARM = "pad_warm"
    PAD_POLYSYNTH = "pad_polysynth"
    PAD_CHOIR = "pad_choir"
    PAD_BOWED = "pad_bowed"
    PAD_METALLIC = "pad_metallic"
    PAD_HALO = "pad_halo"
    PAD_SWEEP = "pad_sweep"

    # Sound Effects
    FX_RAIN = "fx_rain"
    FX_SOUNDTRACK = "fx_soundtrack"
    FX_CRYSTAL = "fx_crystal"
    FX_ATMOSPHERE = "fx_atmosphere"
    FX_BRIGHTNESS = "fx_brightness"
    FX_GOBLINS = "fx_goblins"
    FX_ECHOES = "fx_echoes"
    FX_SCI_FI = "fx_sci_fi"
