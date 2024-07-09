import math

#[
  Calculate primes to approx. waste `n` seconds.
  Stolen from: https://github.com/chvancooten/NimPackt-v1/blob/main/templates/NimPackt-Template.nim#L51
]#
proc calcPrimes*(seconds: int): int {.noinline.} =
    var finalPrime: int = 0
    var max: int = seconds * 68500

    #echo "[*] Sleeping for approx. ", seconds, " seconds"
    for n in countup(2, max):
        var ok: bool = true
        var i: int = 2

        while i.float <= sqrt(n.float):
            if (n mod i == 0):
                ok = false
            inc(i)

        if n <= 1:
            ok = false
        elif n == 2:
            ok = true
        if ok == true:
            finalPrime = n

    return finalPrime

#[
  Checks whether the current binary is
  executed in a AV sandbox by checking the time,
  sleeping and checking the duration of the sleep.
  If the meassured duration  < the sleep time,
  it is probably executed in a Sandbox
]#
proc checkSandbox() =
  # TBD
  return

