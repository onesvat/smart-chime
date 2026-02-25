from pydub import AudioSegment
from pydub.silence import detect_leading_silence
import os

def trim_silence(sound):
    # Başındaki ve sonundaki sessizliği atar
    start_trim = detect_leading_silence(sound)
    end_trim = detect_leading_silence(sound.reverse())
    duration = len(sound)
    return sound[start_trim:duration-end_trim]

def create_tight_chime(strikes_list, filename, interval_ms=1200):
    # Her vuruşun net başladığından emin olalım
    clean_strikes = [trim_silence(s) for s in strikes_list]
    
    # Toplam süreyi vuruş sayısına göre hesapla (Gereksiz uzunluğu at)
    # Son vuruştan sonra 3 saniye çalması yeterli
    total_len = (len(clean_strikes) - 1) * interval_ms + 3000
    combined = AudioSegment.silent(duration=total_len)
    
    for i, bell in enumerate(clean_strikes):
        offset = i * interval_ms
        # Overlay - %100 sesle bindir
        combined = combined.overlay(bell, position=offset)
    
    # Temiz bir bitiş için kısa bir fade_out
    combined = combined.fade_out(500)
    combined.export(os.path.join("sounds/ai_generated", filename), format="wav")

# Sesleri yükle ve normalize et
bell_i = AudioSegment.from_mp3("sounds/new/I_pro.mp3").normalize()
bell_v = AudioSegment.from_mp3("sounds/new/V_pro.mp3").normalize()
bell_x = AudioSegment.from_mp3("sounds/new/X_pro.mp3").normalize()

# Base-4 Alphabet-3
mappings = {
    1:  [bell_i],
    2:  [bell_i, bell_i],
    3:  [bell_i, bell_i, bell_i],
    4:  [bell_v],
    5:  [bell_v, bell_i],
    6:  [bell_v, bell_i, bell_i],
    7:  [bell_v, bell_i, bell_i, bell_i],
    8:  [bell_x],
    9:  [bell_x, bell_i],
    10: [bell_x, bell_i, bell_i],
    11: [bell_x, bell_i, bell_i, bell_i],
    12: [bell_x, bell_v],
    13: [bell_x, bell_v, bell_i]
}

os.makedirs("sounds/ai_generated", exist_ok=True)

for hour, strikes in mappings.items():
    create_tight_chime(strikes, f"hour_{hour}.wav")

print("Tight professional chimes baked.")
