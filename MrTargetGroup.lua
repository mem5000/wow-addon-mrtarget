-- MrTargetGroup
-- =====================================================================
-- Copyright (C) 2014 Lock of War, Developmental (Pty) Ltd
--

local NAME_OPTIONS = {
  'Pikachu', 'Bellsprout', 'Zubat', 'Bulbasaur', 'Charmander', 'Diglett', 'Slowpoke', 'Squirtle', 'Oddish', 'Geodude',
  'Mew', 'Gastly', 'Onix', 'Golduck', 'Spearow', 'Butterfree', 'Charizard', 'Graveler', 'Psyduck', 'Meowth',
  'Krabby', 'Mankey', 'Rattata', 'Metapod', 'Alakazam', 'Pidgeotto', 'Poliwag', 'Kadabra',  'Primeape', 'Caterpie',
  'Gloom', 'Raichu', 'Golem', 'Sandshrew', 'Kakuna', 'Tentacool', 'Vulpix', 'Weedle', 'Jigglypuff', 'Blastoise'
};

local CYRILLIC = {
  ["А"]="A", ["а"]="a", ["Б"]="B", ["б"]="b", ["В"]="V", ["в"]="v", ["Г"]="G", ["г"]="g", ["Д"]="D", ["д"]="d", ["Е"]="E",
  ["е"]="e", ["Ё"]="E", ["ё"]="e", ["Ж"]="Zh", ["ж"]="zh", ["З"]="Z", ["з"]="z", ["И"]="I", ["и"]="i", ["Й"]="I", ["й"]="i",
  ["К"]="K", ["к"]="k", ["Л"]="L", ["л"]="l", ["М"]="M", ["м"]="m", ["Н"]="N", ["н"]="n", ["О"]="O", ["о"]="o", ["П"]="P", ["п"]="p",
  ["Р"]="R",["р"]="r", ["С"]="S", ["с"]="s", ["Т"]="T", ["т"]="t", ["У"]="U", ["у"]="u", ["Ф"]="F", ["ф"]="f", ["Х"]="Kh", ["х"]="kh",
  ["Ц"]="Ts", ["ц"]="ts", ["Ч"]="Ch", ["ч"]="ch", ["Ш"]="Sh", ["ш"]="sh", ["Щ"]="Shch", ["щ"]="shch", ["Ъ"]="Ie", ["ъ"]="ie",
  ["Ы"]="Y", ["ы"]="y", ["Ь"]="X", ["ь"]="x", ["Э"]="E", ["э"]="e", ["Ю"]="Iu", ["ю"]="iu", ["Я"]="Ia", ["я"]="ia"
};

local ROLES = {};
for classID=1, MAX_CLASSES do
  local className, classTag, classID = GetClassInfoByID(classID);
  local numTabs = GetNumSpecializationsForClassID(classID);
  ROLES[classTag] = {};
  for i=1, numTabs do
    local id, name, description, icon, background, role = GetSpecializationInfoForClassID(classID, i);
    ROLES[classTag][name] = { class=className, role=role, id=id, description=description, icon=icon, spec=name };
  end
end

MrTargetGroup = {
  active=false,
  faction=nil,
  update=0,
  tick=1,
  max=15,
  frame=nil,
  frames={},
  units={},
  next_name=1,
  update_units=false
};

MrTargetGroup.__index = MrTargetGroup;

local function SortUnits(u,v)
  if v ~= nil and u ~= nil then
    if u.role == v.role then
      if u.class == v.class then
        if u.name < v.name then
          return true;
        end
      elseif u.class < v.class then
        return true;
      end
    elseif u.role > v.role then
      return true;
    end
  elseif u then
    return true;
  end
end

function MrTargetGroup:New(group)
  local this = setmetatable({}, MrTargetGroup);
  this.units = setmetatable({}, nil); 
  this.frames = setmetatable({}, nil); 
  this.group = group;
  this.frame = CreateFrame('Frame', 'MrTargetGroup'..group, UIParent, 'MrTargetGroupTemplate');
  this.frame:SetScript('OnEvent', function(frame, ...) this:OnEvent(...); end);
  this.frame:SetScript('OnUpdate', function(frame, ...) this:OnUpdate(...); end);
  this.frame:SetScript('OnDragStart', function(frame, ...) this:OnDragStart(...); end);
  this.frame:SetScript('OnDragStop', function(frame, ...) this:OnDragStop(...); end);
  this:InitFrame();  
  this:CreateFrames();
  return this;
end

function MrTargetGroup:Activate()
  self.frame:RegisterEvent('UPDATE_BATTLEFIELD_SCORE'); 
  self.frame:RegisterEvent('PLAYER_TARGET_CHANGED'); 
  self.frame:RegisterEvent('UNIT_TARGET'); 
  self:Show();  
end

function MrTargetGroup:Show()
  if not InCombatLockdown() then
    self:SetFrameStyle();
    self.frame:Show();
  end
end

function MrTargetGroup:SetTarget(frame)
  if frame then
    self.frame.TARGET:ClearAllPoints();
    self.frame.TARGET:SetPoint('TOPRIGHT', frame, 'TOPLEFT', -4, -2);
    self.frame.TARGET:Show(); 
  else
    self.frame.TARGET:Hide();
  end
end

function MrTargetGroup:PlayerTargetChanged()
  if UnitIsEnemy('player', 'playertarget') then
    local target = GetUnitName('playertarget', true);
    for i=1, #self.frames do
      if self.frames[i] then 
        if target == self.frames[i].name then
          self:SetTarget(self.frames[i].frame);
          return;
        end
      end
    end
  end
  self:SetTarget(nil);
end

function MrTargetGroup:SetAssist(frame)
  if frame then
    self.frame.ASSIST:ClearAllPoints();
    self.frame.ASSIST:SetPoint('TOPRIGHT', frame, 'TOPLEFT', -6, -4);
    self.frame.ASSIST:Show();    
  else
    self.frame.ASSIST:Hide(); 
  end
end

function MrTargetGroup:UnitTarget(unit) 
  if UnitIsGroupLeader(unit) then     
    if UnitIsEnemy('player', unit..'target') then
      local target = GetUnitName(unit..'target', true); 
      for i=1, #self.frames do
        if self.frames[i] then 
          if target == self.frames[i].name then
            self:SetAssist(self.frames[i].frame);
            return;
          end
        end
      end
    end
    self:SetAssist(nil);
  end
end

function MrTargetGroup:IsOnBattlefield()
  if not self.active then
    for i=1, GetMaxBattlefieldID() do
      local status, name, size = GetBattlefieldStatus(i);
      if status == 'active' then         
        self.active = true;        
      end
    end
  end
  return self.active;
end

function MrTargetGroup:UpdateBattlefieldScore()
  if self:IsOnBattlefield() then    
    self.faction = GetBattlefieldArenaFaction();
    local numScores = GetNumBattlefieldScores();
    if numScores > 0 then
      self.units = table.wipe(self.units);
      for i=1, numScores do
        local name, _, _, _, _, faction, race, _, class, _, _, _, _, _, _, spec = GetBattlefieldScore(i);
        if faction ~= self.faction then
          table.insert(self.units, { name=name, display=self:GetDisplayName(name), class=class, spec=spec, role=ROLES[class][spec].role, unit=name });
        end
      end
      table.sort(self.units, SortUnits);
      self.update_units = true;
    end
  end
end

function MrTargetGroup:InitFrame()  
  self.frame:RegisterForDrag('RightButton');
  self.frame:SetClampedToScreen(true);
  self.frame:EnableMouse(true);
  self.frame:SetMovable(true);
  self.frame:SetUserPlaced(true);  
end

function MrTargetGroup:CreateFrames()
  for i=1, 15 do
    if not self.frames[i] then self.frames[i] = MrTargetUnit:New(self, i); end
    if i > 1 then
      self.frames[i].frame:ClearAllPoints();
      self.frames[i].frame:SetPoint('TOP', self.frames[i-1].frame, 'BOTTOM', 0, 0);
    end
  end    
end

function MrTargetGroup:Hide()
  if InCombatLockdown() then
    self.frame:RegisterEvent('PLAYER_REGEN_ENABLED');
  else
    self.frame:Hide();
  end  
end

function MrTargetGroup:PlayerRegenEnabled()
  self.frame:UnregisterEvent('PLAYER_REGEN_ENABLED');
  self.frame:Hide();
end

function MrTargetGroup:Destroy()
  for i=1, #self.frames do
    if self.frames[i] then 
      self.frames[i]:Destroy(); 
    end
  end
  self.frame:UnregisterEvent('UPDATE_BATTLEFIELD_SCORE');
  self.frame:UnregisterEvent('PLAYER_TARGET_CHANGED'); 
  self.frame:UnregisterEvent('UNIT_TARGET');  
  self.units = table.wipe(self.units);
  self:Hide();   
end

function MrTargetGroup:OnUpdate(time)
  self.update = self.update + time;
  if self.update < self.tick or (WorldStateScoreFrame and WorldStateScoreFrame:IsShown()) then
    return;
  end
  RequestBattlefieldScoreData();
  if self.update_units and not InCombatLockdown() and #self.units > 0 then
    self.next_name = 1;
    for i=1, #self.frames do
      if self.units[i] then
        self.frames[i]:SetUnit(
          self.units[i].name,
          self.units[i].display, 
          self.units[i].class, 
          self.units[i].spec, 
          self.units[i].role, 
          ROLES[self.units[i].class][self.units[i].spec].icon,
          self.units[i].test
        );
      elseif self.frames[i] then
        self.frames[i]:UnsetUnit();
      end
    end
    self.frame:SetSize(101, math.min(#self.units, #self.frames)*self.frames[1].frame:GetHeight()+14);
    self.update_units = false;
  end
  self:PlayerTargetChanged();
  self.update = 0;
end

function MrTargetGroup:OnEvent(event, ...)
  if event == 'UPDATE_BATTLEFIELD_SCORE' then self:UpdateBattlefieldScore();
  elseif event == 'PLAYER_TARGET_CHANGED' then self:PlayerTargetChanged(...);
  elseif event == 'UNIT_TARGET' then self:UnitTarget(...);
  elseif event == 'PLAYER_REGEN_ENABLED' then self:PlayerRegenEnabled();
  end
end

function MrTargetGroup:GetDisplayName(name)
  if OPTIONS.NAMING == 'Transmute' then
    name = self:Transmute(name);
  elseif OPTIONS.NAMING == 'Transliterate' then
    name = self:Transliterate(name);
  end
  return name;
end

function MrTargetGroup:Transliterate(name)
  if name then
    for c, r in pairs(CYRILLIC) do
      name = string.gsub(name, c, r);
    end
  end
  return name;
end

function MrTargetGroup:Transmute(name)
  if self:IsUTF8(name) then
    name = NAME_OPTIONS[self.next_name];
    self.next_name = self.next_name+1;
  end
  return name;
end

function MrTargetGroup:IsUTF8(name)
  local c,a,n,i = nil,nil,0,1;
  while true do
    c = string.sub(name,i,i);
    i = i + 1;
    if c == '' then
        break;
    end
    a = string.byte(c);
    if a > 191 or a < 127 then
        n = n + 1;
    end
  end
  return (strlen(name) > n*1.5);
end

function MrTargetGroup:SetFrameStyle()
  if OPTIONS.BORDERLESS then self.frame.borderFrame:Hide();
  else self.frame.borderFrame:Show();
  end
end

local function RandomKey(t)
  local keys, i = {}, 1;
  for k in pairs(t) do
    keys[i] = k;
    i = i+1;
  end
  return keys[math.random(1, #keys)];
end

function MrTargetGroup:CreateStub(names)  
  if #self.units == 0 then
    local class, spec = nil, nil;
    for i=1, self.max do
      class = RandomKey(ROLES);
      spec = RandomKey(ROLES[class]);
      table.insert(self.units, { 
        test=true,
        name=names[i], 
        display=self:GetDisplayName(names[i]),
        class=class, 
        spec=spec, 
        role=ROLES[class][spec].role, 
        unit=names[i]
      });
    end
    table.sort(self.units, SortUnits);
  else
    self.next_name = 1;
    for i=1, self.max do
      self.units[i].display = self:GetDisplayName(names[i]);
    end
  end
  self.update_units = true;
end

function MrTargetGroup:GetPosition()
  for i=1, self.frame:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(i);
    return { point, relativeTo, relativePoint, x, y };
  end
end

function MrTargetGroup:OnDragStart()
  if InterfaceOptionsFrame:IsShown() then
    self.frame:ClearAllPoints();
    self.frame:StartMoving();
  end
end

function MrTargetGroup:OnDragStop()
  if InterfaceOptionsFrame:IsShown() then
    OPTIONS.POSITION[self.group] = self:GetPosition();
    self.frame:StopMovingOrSizing();
  end
end