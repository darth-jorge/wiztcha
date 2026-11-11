Application.put_env(:wiztchta, :secret_key_base, String.duplicate("wiztchta-test-secret", 4))
ExUnit.start()
