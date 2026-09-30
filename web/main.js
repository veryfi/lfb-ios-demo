import VeryfiLens from 'veryfi-lens-wasm';

const CLIENT_ID = import.meta.env.VITE_VERYFI_CLIENT_ID;

const HISTORY_KEY = 'lfb-debug-submissions';

// Decoupled mode replaces the /api/document call with customSubmitHandler,
// so onSuccess does not fire for it.
const MODES = {
  document: { label: 'Receipt', config: { lensFlavor: 'document' } },
  long_document: {
    label: 'Long receipt',
    config: { lensFlavor: 'long_document', enableLongReceiptPreview: true },
  },
  checks: { label: 'Check', config: { lensFlavor: 'checks' } },
  anydocs: { label: 'Anydocs', config: { lensFlavor: 'anydocs', enableBlueprintsModal: true } },
  decoupled_document: {
    label: 'Decoupled receipt',
    decoupled: true,
    config: { lensFlavor: 'document', packageMode: false },
  },
};

let currentMode = 'document';

const describeError = (error) => {
  if (error instanceof Error) return `${error.message}\n${error.stack || ''}`;
  if (error && typeof error === 'object') return error.message || error.msg || JSON.stringify(error);
  return String(error);
};

const showScreen = (id) => {
  document.querySelectorAll('.screen').forEach((screen) => {
    screen.style.display = screen.id === id ? 'block' : 'none';
  });
};

const showError = (error) => {
  const node = document.getElementById('boot-error');
  node.style.display = 'block';
  node.textContent = describeError(error);
  showScreen('home');
};

const clearError = () => {
  const node = document.getElementById('boot-error');
  node.style.display = 'none';
  node.textContent = '';
};

const shortenValue = (value, key) => {
  if (typeof value === 'string' && value.length > 180) {
    return `[string ${value.length} chars]`;
  }
  if (Array.isArray(value)) return value.map((item) => shortenValue(item, key));
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([childKey, child]) => [childKey, shortenValue(child, childKey)])
    );
  }
  return value;
};

const readHistory = () => {
  try {
    return JSON.parse(sessionStorage.getItem(HISTORY_KEY)) || [];
  } catch {
    return [];
  }
};

const writeHistory = (entries) => {
  try {
    sessionStorage.setItem(HISTORY_KEY, JSON.stringify(entries));
  } catch (error) {
    console.warn('Could not save submission history', describeError(error));
  }
};

// Images are dropped before saving; sessionStorage is capped at about 5 MB.
const saveSubmission = (mode, result) => {
  const entries = readHistory();
  const entry = {
    id: result?.id ?? null,
    flavor: mode,
    submittedAt: new Date().toISOString(),
    result: shortenValue(result),
  };
  entries.unshift(entry);
  writeHistory(entries);
  renderHistory();
};

const renderHistory = () => {
  const entries = readHistory();
  const table = document.getElementById('history');
  const body = table.querySelector('tbody');
  body.replaceChildren();
  table.style.display = entries.length ? 'table' : 'none';
  document.getElementById('history-empty').style.display = entries.length ? 'none' : 'block';
  entries.forEach((entry) => {
    const row = document.createElement('tr');

    const flavor = document.createElement('td');
    flavor.textContent = MODES[entry.flavor]?.label || entry.flavor;

    const captured = document.createElement('td');
    captured.textContent = new Date(entry.submittedAt).toLocaleTimeString();

    const docId = document.createElement('td');
    docId.textContent = entry.id ?? '—';

    const toggleCell = document.createElement('td');
    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'json-toggle';
    toggle.textContent = 'Show';
    toggle.setAttribute('aria-expanded', 'false');
    toggleCell.appendChild(toggle);

    row.append(flavor, captured, docId, toggleCell);

    const jsonRow = document.createElement('tr');
    jsonRow.className = 'json-row';
    jsonRow.hidden = true;
    const jsonCell = document.createElement('td');
    jsonCell.colSpan = 4;
    const json = document.createElement('pre');
    json.textContent = JSON.stringify(entry.result, null, 2);
    jsonCell.appendChild(json);
    jsonRow.appendChild(jsonCell);

    toggle.addEventListener('click', () => {
      jsonRow.hidden = !jsonRow.hidden;
      toggle.textContent = jsonRow.hidden ? 'Show' : 'Hide';
      toggle.setAttribute('aria-expanded', String(!jsonRow.hidden));
    });

    body.append(row, jsonRow);
  });
};

const handleCustomSubmit = (mode, image, packageInfo) => {
  console.log('customSubmitHandler', packageInfo);
  saveSubmission(mode, { image, packageInfo });
  showScreen('home');
};

const startLens = async (mode) => {
  const { config, decoupled } = MODES[mode];
  currentMode = mode;
  clearError();
  if (!CLIENT_ID) {
    showError('VITE_VERYFI_CLIENT_ID is not set. Add it to .env, run npm run build, then rebuild the app.');
    return;
  }
  showScreen('none');
  try {
    await VeryfiLens.init(CLIENT_ID, {
      ...config,
      ...(decoupled && {
        customSubmitHandler: (image, packageInfo) => handleCustomSubmit(mode, image, packageInfo),
      }),
      debug_mode: true,
      exitButton: true,
      torchButton: true,
      onClose: () => {
        console.log('lens closed');
        showScreen('home');
      },
    });
    console.log('init complete', mode);
    await VeryfiLens.showCamera();
    console.log('showCamera complete');
  } catch (error) {
    console.error('boot failed', describeError(error));
    VeryfiLens.stop();
    showError(error);
  }
};

VeryfiLens.onSuccess((result) => {
  console.log('onSuccess', result);
  saveSubmission(currentMode, result);
  showScreen('home');
});

VeryfiLens.onUpdate((update) => {
  console.log('onUpdate', update);
});

VeryfiLens.onFailure((error) => {
  console.error('onFailure', describeError(error));
});

document.querySelectorAll('#flavors button').forEach((button) => {
  button.addEventListener('click', () => startLens(button.dataset.mode));
});

document.getElementById('history-clear').addEventListener('click', () => {
  sessionStorage.removeItem(HISTORY_KEY);
  renderHistory();
});

renderHistory();
showScreen('home');
