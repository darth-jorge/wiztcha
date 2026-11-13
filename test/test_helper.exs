Application.put_env(:wiztchta, :secret_key_base, String.duplicate("wiztchta-test-secret", 4))
# Tests submit instantly; the minimum fill time has its own tests with explicit opts.
Application.put_env(:wiztchta, :min_time, 0)
ExUnit.start()
