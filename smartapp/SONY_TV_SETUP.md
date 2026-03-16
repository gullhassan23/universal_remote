# Sony TV – Setup & Troubleshooting

Yeh guide batati hai ke Sony TV ko app ke saath kaise use karein aur agar kuch na chale to kya karna hai.

---

## 1. iOS par Sony discover nahi ho raha (SSDP / multicast)

**Kaise kaam karta hai:** App Sony TVs ko dhundne ke liye SSDP (multicast) use karti hai. iOS par kuch WiFi networks multicast restrict karte hain, isliye list mein Sony na bhi dikhe to yeh steps follow karein.

**Kya karna hai:**
- **Phone aur TV dono same WiFi par hon** (same router, same 2.4/5 GHz network).
- Sony TV par **Remote device / IP control** enable karein:
  - **Settings → Network → Home network setup**
  - **Remote device / Renderer** ya **IP Control** → **On**
- Agar phir bhi discover na ho to **router** mein multicast / IGMP enable check karein, ya TV ko ek baar restart karke dubara “Discover” dabayein.

---

## 2. Sony TV settings (connection & PSK)

**Kaise kaam karta hai:** Sony TV app ko control dene ke liye ek **Pre-Shared Key (PSK)** use karti hai. Yeh key TV par set hoti hai; app connect karte waqt isi key se verify karti hai.

**Kya karna hai (zaroori):**
1. **Settings → Network → Home network setup**
2. **Remote device / Renderer** → **On**
3. **IP Control** (ya “Pre-Shared Key”) par jayein aur ek key set karein (jaise `1234` ya koi bhi code).
4. App mein jab Sony TV select karein to **“Sony TV – Pre-Shared Key”** dialog mein wahi key daalein.

Agar key galat ho to “Connection failed” aayega; sahi key daalne par connect ho jana chahiye.

---

## 3. Koi specific key (volume, channel, OK) kaam na kare

**Kaise kaam karta hai:**  
Connect hone ke baad app TV se **getRemoteControllerInfo** call karti hai aur usi TV ke button codes use karti hai. Isse zyada tar Sony models par sahi keys chal jati hain. Agar koi button phir bhi na chale to app pehle TV wale code use karti hai, phir fallback codes.

**Agar phir bhi koi key na chale:**
- **TV model alag ho sakta hai:** Kuch purane/models alag code bhejte hain. App ab TV se codes khud le rahi hai, isliye zyada tar cases cover ho jane chahiye.
- **Manual fix:** Agar aapko pata ho ke kaunsa button ka code alag hai to developer `lib/services/sony_ircc_codes.dart` mein fallback map update kar sakta hai (KEY_* → IRCC code).  
  Ya runtime par TV ka `getRemoteControllerInfo` response dekh kar sahi “name” / “value” match kiya ja sakta hai.

---

## Short checklist

| Step | Kya karna hai |
|------|----------------|
| Same WiFi | Phone + Sony TV same network par |
| TV settings | Remote device / IP Control **On**, **Pre-Shared Key** set |
| App | Sony select karein → PSK dialog mein TV wali key daalein |
| Keys | Connect ke baad volume/channel/navigation TV se auto-codes use karti hai |

Iske baad bhi issue ho to error message (e.g. “Connection failed” / “No TVs found”) dekh kar upar wale sections check karein.
