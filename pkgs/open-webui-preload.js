// Ask Ollama to load the model selected in the chat's dropdown when a draft
// starts, so it loads while the message is being typed instead of after it is
// sent. Runs the same in a browser tab and in the installed PWA.
//
// One preload per draft: the first input in a chat sends it, and only sending a
// message (or moving to another chat) arms the next one.
(() => {
  const originalFetch = window.fetch.bind(window);
  // Path of the chat whose current draft already sent its preload.
  let preloadedChat = null;

  window.fetch = (input, init) => {
    const url = typeof input === 'string' ? input : input?.url ?? '';
    if (url.endsWith('/api/chat/completions')) preloadedChat = null;
    return originalFetch(input, init);
  };

  const authorization = () => ({ Authorization: `Bearer ${localStorage.token}` });

  // The dropdown shows the selected model's name, followed by " +N" when
  // comparing several models; map the name back to the model's id.
  const selectedModel = async () => {
    const label = document.getElementById('model-selector-model-button')?.textContent.trim().replace(/ \+\d+$/, '');
    if (!label) return null;
    const response = await originalFetch('/api/models', { headers: authorization() });
    const models = response.ok ? (await response.json()).data ?? [] : [];
    return models.find((model) => model.name === label || model.id === label)?.id ?? null;
  };

  const preload = async () => {
    const model = await selectedModel();
    if (!model) return;
    // Never cancel this request: dropping it mid-load could abort the load.
    originalFetch('/ollama/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authorization() },
      body: JSON.stringify({ model }),
    }).catch(() => {});
  };

  document.addEventListener(
    'input',
    (event) => {
      if (preloadedChat === location.pathname || !event.target.closest?.('#chat-input')) return;
      preloadedChat = location.pathname;
      preload().catch(() => {});
    },
    true,
  );
})();
