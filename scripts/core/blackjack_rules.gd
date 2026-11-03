class_name BlackjackRules
extends RefCounted
## Règles du Blackjack express (logique pure) : valeur d'une main (as à 1 ou 11), stratégie de
## base sans partage (la donneuse reste sur tous les 17) et issue d'une main.
## Cartes : 1 = as, 2..10, 11..13 = figures (valent 10).


static func value(card: int) -> int:
	return mini(card, 10)


static func total(cards: Array[int]) -> int:
	var sum: int = 0
	var aces: int = 0
	for c: int in cards:
		sum += value(c)
		if c == 1:
			aces += 1
	if aces > 0 and sum + 10 <= 21:
		sum += 10
	return sum


## Main « souple » : un as compté 11 sans dépasser 21.
static func is_soft(cards: Array[int]) -> bool:
	var sum: int = 0
	var aces: bool = false
	for c: int in cards:
		sum += value(c)
		aces = aces or c == 1
	return aces and sum + 10 <= 21


## Décision de la stratégie de base : "hit", "double" ou "stand". `can_double` : premier choix.
## `up` : carte visible de la donneuse (1 = as, compté 11).
static func best(cards: Array[int], up: int, can_double: bool) -> String:
	var tot: int = total(cards)
	var d: int = 11 if up == 1 else value(up)
	var act: String = "hit"
	if is_soft(cards):
		if tot >= 19:
			act = "stand"
		elif tot == 18:
			act = "double" if d >= 3 and d <= 6 else ("stand" if d <= 8 else "hit")
		elif tot == 17:
			act = "double" if d >= 3 and d <= 6 else "hit"
		elif tot >= 15:
			act = "double" if d >= 4 and d <= 6 else "hit"
		else:
			act = "double" if d >= 5 and d <= 6 else "hit"
	else:
		if tot >= 17:
			act = "stand"
		elif tot >= 13:
			act = "stand" if d <= 6 else "hit"
		elif tot == 12:
			act = "stand" if d >= 4 and d <= 6 else "hit"
		elif tot == 11:
			act = "double" if d <= 10 else "hit"
		elif tot == 10:
			act = "double" if d <= 9 else "hit"
		elif tot == 9:
			act = "double" if d >= 3 and d <= 6 else "hit"
	if act == "double" and not can_double:
		# Doubler n'est plus permis : tirer, sauf le 18 souple qui reste.
		act = "stand" if is_soft(cards) and tot == 18 else "hit"
	return act


## Issue d'une main terminée : "win", "lose" ou "push".
static func outcome(player: Array[int], dealer: Array[int]) -> String:
	var p: int = total(player)
	var d: int = total(dealer)
	if p > 21:
		return "lose"
	if d > 21 or p > d:
		return "win"
	return "push" if p == d else "lose"
