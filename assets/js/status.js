import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./config.js";
const el = document.querySelector("#project-status");
const configured = SUPABASE_URL.startsWith("https://") &&
  !SUPABASE_URL.includes("COLE_AQUI") &&
  SUPABASE_ANON_KEY.length > 20 &&
  !SUPABASE_ANON_KEY.includes("COLE_AQUI");
el.textContent = configured
  ? "Configuração pública preenchida. Próxima etapa: validar a conexão e configurar autenticação."
  : "Aguardando Project URL e chave anon/publicable em assets/js/config.js.";
