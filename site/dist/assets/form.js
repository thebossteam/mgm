(function(){
  var form = document.getElementById('form-diagnostico')
  if (!form) return
  var errBox = document.getElementById('form-erro')
  function setErr(msg){ if (msg) { errBox.textContent = msg; errBox.hidden = false } else { errBox.textContent = ''; errBox.hidden = true } }
  function stripAcc(s){ return (s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '') }
  var idem = null
  form.addEventListener('submit', function(e){
    e.preventDefault()
    setErr('')
    function v(id){ var el = document.getElementById(id); return el ? el.value.trim() : '' }
    var nome = v('nome'), email = v('email'), whatsapp = v('whatsapp'), perfil = v('perfil'), faturamento = v('faturamento_mensal'), mensagem = v('mensagem')
    if (!nome || !whatsapp || !email || !perfil) { setErr('Preencha nome, WhatsApp, e-mail e o seu setor para solicitar o diagnóstico. Esses campos são obrigatórios.'); return }
    if (email && !/^\S+@\S+\.\S+$/.test(email)) { setErr('Confira o e-mail digitado antes de enviar.'); return }
    if (!document.getElementById('consentimento').checked) { setErr('Para enviar, é preciso ler e aceitar a Política de Privacidade.'); return }
    if (!idem) idem = 'mgm-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8)
    var row = { nome: nome, email: email || null, whatsapp: whatsapp, perfil: stripAcc(perfil), faturamento_mensal: stripAcc(faturamento) || null, mensagem: mensagem || null, origem: 'site MGM', status: 'novo', idempotency_key: idem }
    var btn = form.querySelector('button[type="submit"]')
    btn.disabled = true
    fetch(window.SUPA_URL + '/rest/v1/leads', {
      method: 'POST',
      headers: { 'content-type': 'application/json', apikey: window.SUPA_KEY, Authorization: 'Bearer ' + window.SUPA_KEY, Prefer: 'return=minimal' },
      body: JSON.stringify([row])
    }).then(function(r){ return r.json().catch(function(){ return {} }).then(function(j){ return { ok: r.ok, j: j } }) }).then(function(res){
      if (!res.ok && !(res.j && res.j.code === '23505')) throw new Error((res.j && res.j.message) || 'Serviço indisponível no momento.')
      window.location.href = '/obrigado/'
    }).catch(function(err){
      setErr(err && err.message ? err.message : 'Serviço indisponível no momento.')
      btn.disabled = false
    })
  })
})()
