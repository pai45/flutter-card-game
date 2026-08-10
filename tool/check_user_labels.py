import json, re
from pathlib import Path

# Labels from the user's image_files message (the cricket ones they attached)
user_labels = """
Zeeshan_Ansari aiden_markram will_jacks rachin_ravindra nitish_kumar_reddy khaleel_ahmed mitchell_marsh
02_Shimron_Hetmyer 04_Pathum_Nissanka 07_Rahul_Tewatia 06_Anrich_Nortje 08_Noor_Ahmad 09_Deepak_Chahar
Bhuvneshwar_Kumar 10_Tim_David Marcus_Stoinis Ishan_Kishan Liam_Livingstone Sai_Sudharsan David_Miller
Varun_Chakaravarthy Wanindu_Hasaranga Mayank_Yadav Tilak_Varma jofra_archer phil_salt cameron_green
shivam_dube mohammed_siraj riyan_parag shreyas_iyer josh_hazlewood abhishek_sharma axar_patel
yuzvendra_chahal matheesha_pathirana mitchell_starc arshdeep_singh rinku_singh kuldeep_yadav
tristan_stubbs venkatesh_iyer mohammed_shami ruturaj_gaikwad kl_rahul sam_curran t_natarajan
jos_buttler rishabh_pant rajat_patidar nicholas_pooran ravindra_jadeja hardik_pandya quinton_de_kock
rohit_sharma 05_Avesh_Khan sunil_narine heinrich_klaasen pat_cummins 03_Sandeep_Sharma jasprit_bumrah
rashid_khan Abdul_Samad Ben_Dwarshuis shubman_gill Abishek_Porel virat_kohli Mayank_Markande
Mukesh_Choudhary Kyle_Jamieson Luke_Wood Kwena_Maphaka Sarfaraz_Khan Shreyas_Gopal Donovan_Ferreira
01_Harshal_Patel Kartik_Tyagi Musheer_Khan Jaydev_Unadkat Rasikh_Salam Manish_Pandey Jayant_Yadav
Vyshak_Vijaykumar Tim_Seifert suryakumar_yadav Matthew_Breetzke Jack_Edwards Allah_Ghazanfar
Cooper_Connolly Jordan_Cox Anshul_Kamboj Arshin_Kulkarni Naman_Dhir Manimaran_Siddharth Aman_Khan
Shubham_Dubey Sameer_Rizvi Swapnil_Singh Jacob_Bethell Anukul_Roy Yudhvir_Singh Arshad_Khan
Corbin_Bosch Aniket_Verma Arjun_Tendulkar Auqib_Nabi_Dar Robin_Minz Eshan_Malinga R_Smaran
Kartik_Sharma Anuj_Rawat Harsh_Dubey Lhuan-dre_Pretorius Vishnu_Vinod Raj_Angad_Bawa
""".split()

def slugify(s):
    s = re.sub(r"^\d+_", "", s)
    s = s.lower().replace("-", "_")
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")

plan = json.loads(Path("tool/cricket_portrait_plan.json").read_text(encoding="utf-8"))
new_slugs = {m["slug"] for m in plan["new"]}
exist_names = {m["card_name"] for m in plan["existing"]}
new_names = {m["card_name"] for m in plan["new"]}

rows = json.loads(Path("tool/player_cards_dump.json").read_text(encoding="utf-8"))
cricket = [r for r in rows if r["sport"]=="cricket"]
by_name_slug = {slugify(r["name"]): r for r in cricket}
# also id
for r in cricket:
    tail = r["id"].split("-",2)[-1]
    by_name_slug.setdefault(slugify(tail), r)

# alias map for known spelling diffs
ALIASES = {
    "varun_chakaravarthy": "varun_chakravarthy",
    "lhuan_dre_pretorius": "lhuandre_pretorius",
    "t_natarajan": "t_natarajan",
    "auqib_nabi_dar": "auqib_nabi",
    "r_smaran": "r_smaran",
}

print("user labels", len(user_labels))
for lab in user_labels:
    s = slugify(lab)
    s2 = ALIASES.get(s, s)
    card = by_name_slug.get(s) or by_name_slug.get(s2)
    if not card:
        # try partial
        hits = [r for r in cricket if s.replace("_","") in slugify(r["name"]).replace("_","") or slugify(r["name"]).replace("_","") in s.replace("_","")]
        status = "NO CARD" if not hits else f"FUZZY {[h['name'] for h in hits]}"
        print(f"  {lab}: {status}")
        continue
    has = card["hasPortrait"]
    in_new = card["name"] in new_names
    print(f"  {lab}: -> {card['name']} has={has} will_fill={in_new and not has}")