# MagicCalc Trick

MagicCalc is built around a party magic effect disguised as a normal iOS-style calculator.

## Performance Flow

1. The magician secretly arms the trick by pressing `AC` at least three times.
2. Participant 1 enters any six digit number.
3. The magician reads that number aloud. Everyone in the audience enters it into their own calculator and presses `+`.
4. Participant 2 enters another six digit number.
5. The magician reads that number aloud. Everyone enters it and presses `+` again.
6. The magician turns the phone face down so the keypad is hidden.
7. Participant 1 blindly presses digits for a final random-looking entry.
8. MagicCalc ignores those blind key presses and displays the calculated completing number.
9. The magician turns the phone over, reads that number aloud, and the audience enters it.
10. The audience sees the sum resolve to the current month, day, hour, and minute.

## Target Number

The target is encoded as:

```text
MMDDHHmm
```

For example, September 27 at 9:14 PM becomes:

```text
09272114
```

A calculator will display that as `9272114`, because leading zeroes are not shown.

The app uses 24 hour time so the result is unambiguous.

## Timing Rule

The final hidden number is selected at the moment the first blind digit is pressed, while the phone is face down.

The magician still needs time to flip the phone over, read the selected number, and let the audience enter it. To keep the reveal from becoming stale at the minute boundary:

- If more than 30 seconds remain in the current minute, MagicCalc targets the current minute.
- If 30 seconds or fewer remain, MagicCalc targets the next minute.

## Formula

MagicCalc tracks the first two six digit entries as a running sum:

```text
firstEntry + secondEntry = visibleSum
```

When the blind entry begins, it calculates:

```text
selectedNumber = targetDateTime - visibleSum
```

The audience then computes:

```text
firstEntry + secondEntry + selectedNumber = targetDateTime
```

## Seven Digit Constraint

The desired final entry is a seven digit number. That is possible when:

```text
1,000,000 <= selectedNumber <= 9,999,999
```

Because the first two numbers and the date/time target can vary, some combinations cannot produce a seven digit completing number. In that case MagicCalc still computes the exact completing number, but the operator should reset and start again if the performance specifically requires a seven digit final entry.

## Operator Signal

After the hidden number is selected, the app may show a tiny operator status:

- `This minute`: the chosen number targets the current minute.
- `Next minute`: the chosen number targets the next minute.
- `Needs reset`: the exact completing value is not seven digits.
