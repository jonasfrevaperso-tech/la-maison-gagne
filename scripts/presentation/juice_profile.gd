class_name JuiceProfile
extends RefCounted
## Paramètres visuels du « jus », tous mis à l'échelle par l'intensité (0..1) des options.
## Constantes de présentation uniquement (aucune n'affecte la logique).

const REDUCED_CAP: float = 0.35
const SHAKE_MAX_PX: float = 22.0
const SHAKE_DECAY: float = 6.0
const HITSTOP_MAX: float = 0.12
const FLASH_ALPHA_MAX: float = 0.45
const FLOAT_TEXT_RISE: float = 90.0
const FLOAT_TEXT_TIME: float = 0.9
const EVENT_STEP_TIME: float = 0.42
const EVENT_STEP_MIN: float = 0.12
const COUNT_UP_TIME: float = 0.6
const PITCH_STEP: float = 0.06
const PITCH_MAX: float = 2.2
const CARD_TILT_DEG: float = 9.0
const BALL_SPIN_TIME: float = 3.6
const BALL_SLOWMO_FACTOR: float = 0.35
const PARTICLE_COUNT_MAX: int = 90
const CELEBRATION_TIERS: Array[float] = [1.0, 2.0, 5.0, 12.0]  # multiples de la dette restante / tour
const CELEBRATION_KEYS: Array[String] = ["CELEB_GOOD", "CELEB_HUGE", "CELEB_JACKPOT", "CELEB_BANK"]


static func intensity() -> float:
	return Settings.juice()


static func shake_px(amount: float) -> float:
	return SHAKE_MAX_PX * clampf(amount, 0.0, 1.0) * intensity() * Settings.f("juice", "shake")


static func step_time() -> float:
	return maxf(EVENT_STEP_TIME / maxf(Settings.speed(), 1.0), EVENT_STEP_MIN / maxf(Settings.speed(), 1.0))


static func flashes_enabled() -> bool:
	return Settings.b("juice", "flashes") and not Settings.b("juice", "reduced_motion")
