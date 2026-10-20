.pragma library

var kinds = ["hachiware", "chiikawa", "usagi", "momonga"];

var names = {
  "hachiware": "Hachiware",
  "chiikawa": "Chiikawa",
  "usagi": "Usagi",
  "momonga": "Momonga"
};

var roles = {
  "hachiware": ["idle", "idle2", "idle3", "walk", "happy", "happy2", "dance", "dance2", "rest", "love"],
  "chiikawa": ["idle", "idle2", "idle3", "idle4", "idle5", "walk", "run", "happy", "happy2", "dance", "rest", "love", "jump", "cry"],
  "usagi": ["idle", "idle3", "idle4", "idle5", "idle6", "idle7", "walk", "run", "happy", "dance", "rest", "love"],
  "momonga": ["idle", "happy", "dance", "rest", "cry", "cry2"]
};

var defaults = {
  "pet": "hachiware",
  "sound": "chiikawa",
  "launcher": "hachiware",
  "lock": ["hachiware", "chiikawa", "usagi"]
};

function has(kind, role) {
  return (roles[kind] || []).indexOf(role) >= 0;
}

function variants(kind, role) {
  var re = new RegExp("^" + role + (/\d$/.test(role) ? "$" : "\\d*$"));
  return (roles[kind] || []).filter(function (r) { return re.test(r); });
}

function idles(kind) {
  return (roles[kind] || []).filter(function (r) { return r.indexOf("idle") === 0; });
}
