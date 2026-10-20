extends Node
## 武将名册：属性、兵器、绝技、台词、AI 性格。

const ORDER := ["zhaoyun", "guanyu", "zhangfei", "machao", "huangzhong", "xuchu", "dianwei", "lvbu", "xusheng"]

var data := {
	"zhaoyun": {
		"name": "赵云", "zi": "子龙", "home": "常山", "call": "常山赵子龙", "epithet": "一身是胆",
		"faction": "蜀", "weapon": "spear", "weapon_name": "龙胆亮银枪", "horse": "照夜玉狮子",
		"color": Color(0.62, 0.82, 1.0), "color2": Color(0.95, 0.97, 1.0),
		"stats": {"wu": 96, "tong": 90, "su": 97, "dan": 98},
		"hp": 1290, "size": 1.0,
		"ult": {"id": "qijin", "name": "七进七出", "desc": "化作白影连穿敌阵七次，末枪贯日。"},
		"ai": {"aggression": 0.62, "patience": 0.55, "parry": 0.70, "dodge": 0.75, "combo": 0.80,
			"jump": 0.30, "feint": 0.35, "zone": 0.0, "honor": 0.75, "taunt": 0.25, "ult_style": "drama"},
		"lines": {
			"self": "吾乃常山赵子龙也！",
			"call": "来将何人？速速报名！",
			"taunt": ["子龙一身都是胆！", "看枪！", "尔等鼠辈，也敢拦路！"],
			"ult": "七进七出，谁敢阻我！",
			"win": ["常山赵子龙在此，还有谁！", "承让了。"],
			"lose": "主公……子龙尽力了……",
			"honor": "子龙不欺步战之人——下马再战！",
			"unhorsed": "马失前蹄……再来！",
			"low": "子龙还能战！",
		},
	},
	"guanyu": {
		"name": "关羽", "zi": "云长", "home": "河东", "call": "河东关云长", "epithet": "武圣",
		"faction": "蜀", "weapon": "glaive", "weapon_name": "青龙偃月刀", "horse": "赤兔",
		"color": Color(0.35, 0.95, 0.55), "color2": Color(1.0, 0.85, 0.35),
		"stats": {"wu": 97, "tong": 95, "su": 82, "dan": 94},
		"hp": 1420, "size": 1.04,
		"ult": {"id": "tuodao", "name": "青龙拖刀斩", "desc": "拖刀诈败，回身一记青龙刀气横扫千军。"},
		"ai": {"aggression": 0.50, "patience": 0.75, "parry": 0.80, "dodge": 0.40, "combo": 0.65,
			"jump": 0.12, "feint": 0.65, "zone": 0.0, "honor": 0.9, "taunt": 0.2, "ult_style": "finisher"},
		"lines": {
			"self": "吾乃河东解良关云长！",
			"call": "插标卖首之辈，报上名来！",
			"taunt": ["关某视之，如土鸡瓦犬耳！", "青龙偃月，斩将如麻！"],
			"ult": "看我青龙偃月！",
			"win": ["温酒斩华雄，不过如此。", "关某之刀，从无虚发。"],
			"lose": "关某……一世英名……",
			"honor": "关某岂可欺你步战？下马！",
			"unhorsed": "赤兔受惊……无妨！",
			"low": "关某尚有一刀！",
		},
	},
	"zhangfei": {
		"name": "张飞", "zi": "翼德", "home": "燕人", "call": "燕人张翼德", "epithet": "万人敌",
		"faction": "蜀", "weapon": "snake", "weapon_name": "丈八蛇矛", "horse": "乌云",
		"color": Color(0.85, 0.35, 1.0), "color2": Color(1.0, 0.35, 0.25),
		"stats": {"wu": 98, "tong": 78, "su": 84, "dan": 97},
		"hp": 1360, "size": 1.03,
		"ult": {"id": "nuhou", "name": "当阳怒吼", "desc": "一声断喝震慑敌将，蛇矛乱刺接连不断。"},
		"ai": {"aggression": 0.86, "patience": 0.28, "parry": 0.5, "dodge": 0.38, "combo": 0.76,
			"jump": 0.20, "feint": 0.10, "zone": 0.0, "honor": 0.45, "taunt": 0.55, "ult_style": "eager"},
		"lines": {
			"self": "燕人张翼德在此！",
			"call": "呔！来者何人！",
			"taunt": ["哇呀呀呀——！", "谁敢与俺决一死战！", "痛快！再来！"],
			"ult": "燕人张飞在此——！",
			"win": ["痛快！痛快！还有谁！", "俺的蛇矛可不认人！"],
			"lose": "俺……俺不服……",
			"honor": "下马！俺跟你步战！",
			"unhorsed": "哇呀！摔得好！再来！",
			"low": "俺还没打够！",
		},
	},
	"machao": {
		"name": "马超", "zi": "孟起", "home": "西凉", "call": "西凉锦马超", "epithet": "神威天将军",
		"faction": "蜀", "weapon": "spear", "weapon_name": "虎头湛金枪", "horse": "白龙驹",
		"color": Color(0.45, 0.62, 1.0), "color2": Color(1.0, 1.0, 1.0),
		"stats": {"wu": 96, "tong": 84, "su": 98, "dan": 93},
		"hp": 1320, "size": 1.0, "mount_dmg": 1.06,
		"ult": {"id": "tieqi", "name": "西凉铁骑", "desc": "引西凉铁骑虚影冲阵，万马踏过，一枪穿心。"},
		"ai": {"aggression": 0.72, "patience": 0.45, "parry": 0.64, "dodge": 0.62, "combo": 0.78,
			"jump": 0.25, "feint": 0.45, "zone": 0.0, "honor": 0.6, "taunt": 0.3, "ult_style": "eager"},
		"lines": {
			"self": "西凉锦马超在此！",
			"call": "来将可敢通名？",
			"taunt": ["西凉铁骑，所向披靡！", "看枪！"],
			"ult": "西凉铁骑，随我冲锋！",
			"win": ["锦马超之名，岂是虚传！"],
			"lose": "父仇未报……可恨……",
			"honor": "马超亦下马，与你一战！",
			"unhorsed": "可恶！步战亦能取你首级！",
			"low": "西凉男儿，死战不退！",
		},
	},
	"huangzhong": {
		"name": "黄忠", "zi": "汉升", "home": "南阳", "call": "南阳黄汉升", "epithet": "老当益壮",
		"faction": "蜀", "weapon": "bow", "weapon_name": "宝雕弓", "horse": "黄骠马",
		"color": Color(1.0, 0.78, 0.25), "color2": Color(1.0, 0.45, 0.15),
		"stats": {"wu": 93, "tong": 88, "su": 80, "dan": 90},
		"hp": 1450, "size": 0.98,
		"ult": {"id": "chuanyang", "name": "百步穿杨", "desc": "锁定敌将，一箭贯日；距离越远，伤害越重。随后箭雨倾盆。"},
		"ai": {"aggression": 0.40, "patience": 0.80, "parry": 0.55, "dodge": 0.65, "combo": 0.55,
			"jump": 0.20, "feint": 0.40, "zone": 0.9, "honor": 0.8, "taunt": 0.2, "ult_style": "drama"},
		"lines": {
			"self": "老将黄汉升在此！",
			"call": "老夫箭下，不斩无名之将！",
			"taunt": ["老当益壮，宁移白首之心！", "百步之内，取你首级！"],
			"ult": "百步穿杨！",
			"win": ["老夫宝刀未老！", "谁说老夫老矣？"],
			"lose": "老夫……老矣……",
			"honor": "老夫亦下马，与你步战！",
			"unhorsed": "老夫的腿脚，还灵便得很！",
			"low": "老夫尚能开弓！",
		},
	},
	"xuchu": {
		"name": "许褚", "zi": "仲康", "home": "谯国", "call": "谯国许仲康", "epithet": "虎痴",
		"faction": "魏", "weapon": "cleaver", "weapon_name": "火云刀", "horse": "栗色马",
		"color": Color(1.0, 0.55, 0.18), "color2": Color(1.0, 0.25, 0.1),
		"stats": {"wu": 94, "tong": 74, "su": 72, "dan": 90},
		"hp": 1440, "size": 1.06,
		"ult": {"id": "luoyi", "name": "虎痴裸衣", "desc": "解衣赤膊，霸体狂战；跃起一刀劈地开山。"},
		"ai": {"aggression": 0.78, "patience": 0.34, "parry": 0.42, "dodge": 0.28, "combo": 0.66,
			"jump": 0.18, "feint": 0.05, "zone": 0.0, "honor": 0.5, "taunt": 0.5, "ult_style": "eager"},
		"lines": {
			"self": "谯国许仲康在此！",
			"call": "哪来的家伙，报上名来！",
			"taunt": ["吃俺一刀！", "哈哈，力气不错！再来！"],
			"ult": "虎痴来也——脱了衣裳再战！",
			"win": ["这一刀，痛快！"],
			"lose": "俺……还没打够……",
			"honor": "俺也下来，跟你比比力气！",
			"unhorsed": "马不顶用，俺用脚走！",
			"low": "疼？俺不知道疼！",
		},
	},
	"dianwei": {
		"name": "典韦", "zi": "", "home": "陈留", "call": "陈留典韦", "epithet": "古之恶来",
		"faction": "魏", "weapon": "dual", "weapon_name": "双铁戟", "horse": "青骢马",
		"color": Color(1.0, 0.25, 0.35), "color2": Color(0.75, 0.75, 0.8),
		"stats": {"wu": 95, "tong": 76, "su": 76, "dan": 96},
		"hp": 1420, "size": 1.05,
		"ult": {"id": "eli", "name": "古之恶来", "desc": "双戟化作旋风，绞杀近身之敌，末了双戟劈落。"},
		"ai": {"aggression": 0.85, "patience": 0.30, "parry": 0.40, "dodge": 0.30, "combo": 0.85,
			"jump": 0.15, "feint": 0.05, "zone": 0.0, "honor": 0.5, "taunt": 0.35, "ult_style": "eager"},
		"lines": {
			"self": "陈留典韦在此，谁敢上前！",
			"call": "来者何人！",
			"taunt": ["古之恶来，在此！", "双戟之下，无人近身！"],
			"ult": "双戟乱舞——！",
			"win": ["主公无恙，典韦便无恙！"],
			"lose": "主公……快走……",
			"honor": "下马！典韦步战更凶！",
			"unhorsed": "无妨！典韦步战更凶！",
			"low": "典韦在，主公在！",
		},
	},
	"lvbu": {
		"name": "吕布", "zi": "奉先", "home": "九原", "call": "九原吕奉先", "epithet": "飞将",
		"faction": "群", "weapon": "halberd", "weapon_name": "方天画戟", "horse": "赤兔马",
		"color": Color(1.0, 0.18, 0.12), "color2": Color(1.0, 0.75, 0.2),
		"stats": {"wu": 100, "tong": 86, "su": 94, "dan": 92},
		"hp": 1360, "size": 1.05,
		"ult": {"id": "wushuang", "name": "天下无双", "desc": "飞身劈落，方天画戟三连横扫，末戟挑飞敌将。"},
		"ai": {"aggression": 0.78, "patience": 0.42, "parry": 0.6, "dodge": 0.45, "combo": 0.78,
			"jump": 0.22, "feint": 0.20, "zone": 0.0, "honor": 0.0, "taunt": 0.45, "ult_style": "finisher"},
		"lines": {
			"self": "吾乃九原吕奉先！",
			"call": "何人敢挡我吕布！",
			"taunt": ["土鸡瓦狗，也配与我交手？", "人中吕布，马中赤兔！", "一起上吧！"],
			"ult": "天下无双——！",
			"win": ["天下英雄，不过如此！", "还有谁？！"],
			"lose": "怎……怎么可能……",
			"honor": "",
			"unhorsed": "赤兔！……也罢，步战亦能杀你！",
			"low": "吕布岂会败于此地！",
		},
	},
	"xusheng": {
		"name": "徐盛", "zi": "文向", "home": "琅琊", "call": "琅琊徐文向", "epithet": "江表虎臣",
		"faction": "吴", "weapon": "spear", "weapon_name": "断江枪", "horse": "苍骢",
		"color": Color(0.35, 0.78, 0.82), "color2": Color(1.0, 0.85, 0.45),
		"stats": {"wu": 95, "tong": 91, "su": 94, "dan": 93},
		"hp": 1400, "size": 1.0,
		"ult": {"id": "yicheng", "name": "百里疑城", "desc": "连夜筑疑城数百里，虚兵四起、箭雨蔽江，敌将惊疑之际一枪穿心。"},
		"ai": {"aggression": 0.62, "patience": 0.55, "parry": 0.74, "dodge": 0.72, "combo": 0.78,
			"jump": 0.22, "feint": 0.40, "zone": 0.0, "honor": 0.70, "taunt": 0.25, "ult_style": "drama"},
		"lines": {
			"self": "吾乃琅琊徐文向！",
			"call": "江东子弟，岂惧北兵！",
			"taunt": ["江东儿郎，从不畏战！", "看枪！", "尔等北军，也敢窥江？"],
			"ult": "百里疑城，草木皆兵！",
			"win": ["江表虎臣，岂是虚名！", "江东子弟，从不辱命。"],
			"lose": "盛……愧对主上……",
			"honor": "盛亦下马，与你步战！",
			"unhorsed": "马失前蹄……无妨！",
			"low": "江东儿郎，死战不退！",
		},
	},
}

# 宿命对决的专属台词（A 对 B 说）
var rivalry := {
	"zhangfei|lvbu": "三姓家奴休走！燕人张飞在此！",
	"lvbu|zhangfei": "环眼贼，又是你！",
	"guanyu|lvbu": "吕布！今日便叫你知道关某的刀！",
	"lvbu|guanyu": "红脸贼，报上名来受死！",
	"zhaoyun|lvbu": "飞将吕布？子龙今日便来会会！",
	"lvbu|zhaoyun": "白袍小将，倒有几分胆色。",
	"huangzhong|guanyu": "关云长，长沙一别，老夫的箭可还记得？",
	"guanyu|huangzhong": "老将军箭下留情之恩，关某今日以刀相报！",
	"xuchu|machao": "马儿！再来与俺斗三百合！",
	"machao|xuchu": "虎痴！潼关未分胜负，今日了断！",
	"dianwei|xuchu": "仲康，你我同为主公护卫，今日较量一番！",
	"xuchu|dianwei": "哈哈，典韦兄弟，俺早想跟你比比！",
	"machao|zhangfei": "张翼德！葭萌关夜战，今日再续！",
	"zhangfei|machao": "马儿休走！葭萌关还没打完！",
	"zhaoyun|machao": "孟起，同为五虎，切磋几合！",
	"machao|zhaoyun": "子龙，请赐教！",
	"dianwei|lvbu": "吕布！濮阳之仇，今日来报！",
	"lvbu|dianwei": "又是你这恶汉！",
	"xusheng|xuchu": "魏将休狂！江东徐盛在此！",
	"xuchu|xusheng": "东吴的小子？吃俺一刀！",
}


func ids() -> Array:
	return ORDER.duplicate()


func get_def(id: String) -> Dictionary:
	return data.get(id, data["zhaoyun"])


func display_name(id: String) -> String:
	var d := get_def(id)
	return d["name"]


func line(id: String, key: String) -> String:
	var l = get_def(id)["lines"].get(key, "")
	if l is Array:
		return l[randi() % l.size()] if l.size() > 0 else ""
	return l


func rivalry_line(a: String, b: String) -> String:
	return rivalry.get(a + "|" + b, "")


## 属性换算
func power_mult(id: String) -> float:
	return 0.62 + get_def(id)["stats"]["wu"] / 260.0


func defense_mult(id: String) -> float:
	return 1.0 - (get_def(id)["stats"]["tong"] - 60.0) / 420.0


func speed_mult(id: String) -> float:
	return 0.86 + get_def(id)["stats"]["su"] / 700.0
