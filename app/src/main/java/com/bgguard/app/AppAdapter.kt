package com.bgguard.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.bgguard.app.databinding.ItemAppBinding

class AppAdapter(
    private val onToggle: (AppInfo, Boolean) -> Unit
) : RecyclerView.Adapter<AppAdapter.VH>() {

    private var items = listOf<AppInfo>()

    fun submit(list: List<AppInfo>) {
        items = list
        notifyDataSetChanged()
    }

    inner class VH(val b: ItemAppBinding) : RecyclerView.ViewHolder(b.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val b = ItemAppBinding.inflate(
            LayoutInflater.from(parent.context), parent, false)
        return VH(b)
    }

    override fun onBindViewHolder(holder: VH, position: Int) {
        val app = items[position]
        holder.b.appName.text = app.label
        holder.b.pkgName.text = app.packageName
        holder.b.appIcon.setImageDrawable(app.icon)

        holder.b.checkbox.setOnCheckedChangeListener(null)
        holder.b.checkbox.isChecked = app.whitelisted

        holder.b.checkbox.setOnCheckedChangeListener { _, checked ->
            onToggle(app, checked)
        }

        holder.b.root.setOnClickListener {
            holder.b.checkbox.isChecked = !holder.b.checkbox.isChecked
        }
    }

    override fun getItemCount() = items.size
}
